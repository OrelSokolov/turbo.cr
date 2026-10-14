# Turbo.signed_stream_verifier_key_from_secret! — railtie-клей деривации
# ключа подписи стримов из secret_key_base. Вектор снят независимой
# реализацией (python: PBKDF2-HMAC-SHA256, 1000 итераций, 64 байта;
# подпись HMAC-SHA256 над strict-base64(json) конвертом MessageVerifier).
require "spec"
require "../src/turbo_cr"

describe "Turbo.signed_stream_verifier_key_from_secret!" do
  it "derives the Rails 8.1 message_verifier(:turbo_streams) key" do
    Turbo.signed_stream_verifier_key_from_secret!("0123456789abcdef0123456789abcdef")

    value = "gid://campfire/Room/104393281:messages"
    token = "ImdpZDovL2NhbXBmaXJlL1Jvb20vMTA0MzkzMjgxOm1lc3NhZ2VzIg==--" \
            "f20bf6566110bf2df393ff99eb6f391fc48ee2724c0eced85d881fb724d12493"
    Turbo.signed_stream_verifier.generate(value).should eq(token)
    Turbo::Streams::StreamName.verified_stream_name(token).should eq(value)
  end
end
