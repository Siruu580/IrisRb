require 'websocket-client-simple'
require 'net/http'
require 'uri'
require 'json'
require 'logger'
require 'listen'
require 'open-uri'
require 'base64'

module IrisRb
  class Client
    def initialize(url:, hot_reload: false)
      if url =~ %r{^https?://}
        @http_url = url
        @ws_url = url.sub(%r{/$}, "") + "/ws"
      else
        raise ArgumentError, "url must start with http:// or https://"
      end
      @logger = Logger.new($stdout)
      @current_room_id = nil
      connect_websocket
      start_hot_reload if hot_reload
    end

    def connect_websocket
      @ws = WebSocket::Client::Simple.connect(@ws_url)
      client = self

      @ws.on :open do
        client.log_info("WebSocket connected")
      end

      @ws.on :message do |msg|
        client.handle_message(msg.data)
      end

      @ws.on :error do |e|
        client.log_error("WebSocket error: #{e.message}")
      end

      @ws.on :close do |e|
        client.log_info("WebSocket disconnected: #{e.inspect}")
      end
    end

    def handle_message(raw_msg)
      parsed = parse_json(raw_msg)
      return unless parsed

      json = parsed["json"]
      json = parse_json(json) if json.is_a?(String)
      json ||= {}

      attachment = json["attachment"]
      attachment = parse_json(attachment) if attachment.is_a?(String)
      attachment ||= {}

      v = json["v"]
      v = parse_json(v) if v.is_a?(String)
      v ||= {}

      chat = {
        room: {
          id: json["chat_id"],
          name: parsed["room"]
        },
        sender: {
          id: json["user_id"],
          name: parsed["sender"]
        },
        message: {
          id: json["id"],
          type: json["type"],
          content: json["message"],
          attachment: attachment,
          v: v
        },
        raw: parsed["json"]
      }

      extended_chat = extend_chat(chat)

      @current_room_id = extended_chat[:room][:id]
      $current_chat = extended_chat
      $client = self
      $msg = extended_chat[:message][:content].strip

      Thread.new do
        event = event_type(v)
        case event
        when :message
          on_message(extended_chat) if defined?(on_message)
        when :new_member
          on_newmem(extended_chat) if defined?(on_newmem)
        when :del_member
          on_delmem(extended_chat) if defined?(on_delmem)
        when :unknown
          # do nothing?
        end
      end
    rescue => e
      log_error("Failed to handle message: #{e}")
    end

    def reply(message)
      if @current_room_id.nil?
        raise ArgumentError, "No current room ID available. Make sure a chat event has been processed first."
      end
      
      send_reply(@current_room_id, message, "text")
    end

    def send_image(room_id, image_path_or_base64)
      if File.exist?(image_path_or_base64)
        image_base64 = image_base64(image_path_or_base64)
        if image_base64.nil?
          log_error("이미지 파일을 읽을 수 없습니다: #{image_path_or_base64}")
          return nil
        end
        send_reply(room_id, image_base64, "image")
      else
        send_reply(room_id, image_path_or_base64, "image")
      end
    end

    def send_image_multiple(room_id, image_base64s)
      send_reply(room_id, image_base64s, "image_multiple")
    end

    def query(query_str, bind = [])
      endpoint = URI.join(@http_url, "/query")
      payload = { query: query_str, bind: bind }.to_json
      headers = { "Content-Type" => "application/json" }

      res = post_request(endpoint, payload, headers)
      if res.is_a?(Net::HTTPSuccess)
        body = JSON.parse(res.body)
        body["data"]
      else
        log_error("Failed to run query: #{res.body}")
        nil
      end
    rescue => e
      log_error("Query error: #{e}")
      nil
    end

    def log_info(msg)
      @logger ? @logger.info(msg) : puts(msg)
    end

    def log_error(msg)
      @logger ? @logger.error(msg) : puts(msg)
    end

    def start_hot_reload
      current_dir = File.expand_path(File.dirname($0))
      listener = Listen.to(current_dir, only: /\.rb$/) do |_modified, _added, _removed|
        exec("ruby #{$0} #{ARGV.join(' ')}")
      end
      listener.start
    end

    private

    def send_reply(room_id, data, type)
      endpoint = URI.join(@http_url, "/reply")
      payload = {
        type: type,
        room: room_id,
        data: data
      }.to_json
      headers = { "Content-Type" => "application/json" }

      res = post_request(endpoint, payload, headers)
      if res.is_a?(Net::HTTPSuccess)
        log_info("Successfully sent #{type}: #{res.code}")
      else
        log_error("Failed to send #{type}: #{res.body}")
      end
    rescue => e
      log_error("Send #{type} error: #{e}")
    end

    def post_request(uri, payload, headers)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = false
      req = Net::HTTP::Post.new(uri.request_uri, headers)
      req.body = payload
      http.request(req)
    end

    def parse_json(str)
      JSON.parse(str)
    rescue JSON::ParserError
      nil
    end

    def event_type(v_hash)
      origin = v_hash["origin"]
      case origin
      when "MSG" then :message
      when "NEWMEM" then :new_member
      when "DELMEM" then :del_member
      else :unknown
      end
    end

    def extend_chat(chat)
      extend_with_room_type(chat)
      extend_with_member_info(chat)
    end

    def extend_with_room_type(chat)
      query_str = "SELECT type FROM chat_rooms where id = ?"
      room_id = chat[:room][:id]

      result = query(query_str, [room_id])
      type = result&.first&.fetch("type", "Unknown") || "Unknown"
      chat[:room][:type] = type
      chat
    end

    def extend_with_member_info(chat)
      user_id = chat[:sender][:id]
      
      result = query("SELECT * FROM chat_logs WHERE user_id = ? ORDER BY id ASC LIMIT 1", [user_id])
      
      nickname = nil
      if result && result.first
        row = result.first
        message = row["message"]
        
        if message
          begin
            feed = JSON.parse(message)
            if feed && feed["feedType"] == 4
              member = feed["members"]&.first
              nickname = member["nickName"] if member
            end
          rescue JSON::ParserError
          end
        end
      end
      
      if nickname
        chat[:sender][:name] = nickname
      end
      
      chat
    end

    public

    def image_base64(image_path)
      begin
        if File.exist?(image_path)
          image_data = File.binread(image_path)
          Base64.strict_encode64(image_data)
        else
          nil
        end
      rescue => e
        nil
      end
    end

    private

    def decrypt(enc, data, user_id)
      endpoint = URI.join(@http_url, "/decrypt")
      payload = { enc: enc, b64_ciphertext: data, user_id: user_id }.to_json
      headers = { "Content-Type" => "application/json" }

      res = post_request(endpoint, payload, headers)
      if res.is_a?(Net::HTTPSuccess)
        body = JSON.parse(res.body)
        body["plain_text"] || data
      else
        log_error("Failed to decrypt: #{res.body}")
        data
      end
    rescue => e
      log_error("Decrypt error: #{e}")
      data
    end

    public
  end
end

def reply(message)
  $client&.reply(message)
end

def send_image(room_id, file_path)
  $client.send_image(room_id, file_path)
end

def msg
  $msg
end