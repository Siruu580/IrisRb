# IrisRb

[Iris](https://github.com/dolidolih/Iris) 를 기반으로 루비로 포팅한 레포

## 설치

### 필요한것
 Ruby 3.4.0 이상

### 사용법

```bash
gem install iris_ruby
```

```ruby
ruby irisrb.rb
```

### 예제코드

```ruby
require_relative 'lib/iris_rb/client'

def on_message(chat)
  if msg == ".hi"
    reply("Hello #{chat[:sender][:name]}")
  elsif msg == ".이미지"
    send_image(chat[:room][:id], "./image/example.jpg")
  end
end

def on_newmem(chat)
  reply("#{chat[:sender][:name]}님 환영합니다!")
end

def on_delmem(chat)
  reply("#{chat[:sender][:name]}님 안녕히 가세요!")
end

client = IrisRb::Client.new(
  url: "http://localhost:3000",
  hot_reload: true
)

sleep
```

### 나머지 문법은 [Iris](https://github.com/dolidolih/Iris) 문서를 참고해보세요

### 편의성 기능

### Hot Reload

개발 중에는 `hot_reload: true` 옵션을 사용하여 파일 변경 시 자동으로 재시작할 수 있습니다:

```ruby
client = IrisRb::Client.new(
  url: "http://localhost:3000",
  hot_reload: true
)
```

해당 디렉터리에서 `.rb` 확장자인 파일이 변경되면 자동으로 재시작됩니다.

## 버전

현재 버전: **0.0.1** (Discord)
