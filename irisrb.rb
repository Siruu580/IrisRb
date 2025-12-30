require_relative 'lib/iris_rb/client'

def on_message(chat)
  if msg == ".hi"
    reply("Hello #{chat[:sender][:name]}")
  elsif msg == ".tt"
    send_image(chat[:room][:id], "./image/qwer.jpg")
  end
end

def on_newmem(chat) # join member
  reply("#{chat[:sender][:name]}님 환영합니다!")
end

def on_delmem(chat) # leave member
  reply("#{chat[:sender][:name]}님 안녕히 가세요!")
end

client = IrisRb::Client.new(
  url: "http://localhost:3000", # use local range address
  hot_reload: true
)

sleep