require "test_helper"

class Flight::DrawerTest < Minitest::Test
  def test_draw
    credential = {
      "gcp" => {
        "GCP_CREDENTIALS_JSON" => '"JSON"',
      },
      "smtp" => {
        "SMTP_SERVER" => "SMTP-SERVER",
        "SMTP_PORT" => "SMTP-PORT",
        "SMTP_USER" => "SMTP-USER",
        "SMTP_PASSWORD" => "SMTP-PASSWORD",
      },
    }
    contents = {
      "reset-email" => {
        "EMAIL_FROM" => "EMAIL-FROM",
        "EMAIL_SUBJECT" => "EMAIL-SUBJECT",
        "EMAIL_BODY" => <<EMAIL_BODY
EMAIL
BODY
EMAIL_BODY
      },
    }

    router = Flight::Router::Drawer.new(
      env: "development",
      output_dir: File.expand_path("../routes",__FILE__),
    )
    router.map do
      set :domain, "habit.getto.systems"
      set :origin, env(
        production:  "https://#{map[:domain]}",
        development: "http://localhost:12080",
      )
      group :image do
        set :auth,           "phoenix",  "0.0.0-pre23"
        set :datastore,      "diplomat", "0.0.0-pre14", env: credential["gcp"]
        set :reset_password, "phoenix",  "0.0.0-pre6",  env: credential["smtp"].merge(
          LOGIN_URL: "#{map[:origin]}/login/direct.html",
        )
      end
      group :auth do
        set :direct,   method: "header", expire: 600,    verify: 600
        set :api,      method: "header", expire: 604800, verify: 1209600
        set :download, method: "get",    expire: 600
      end
    end

    router.app do
      set :origin, map[:origin]
    end

    config = router.build("/getto/habit") do
      namespace :token do
        api :auth do
          [
            [:auth,      "format-for-auth", kind: "User"],
            [:datastore, "find", kind: "User"],
            [:auth,      "sign", auth: :api],
          ]
        end
        api :direct, auth: :direct do
          [ [:auth, "renew", auth: :api, verify: :direct] ]
        end
        api :renew, auth: :api do
          [ [:auth, "renew", auth: :api, verify: :api] ]
        end
        api :reset do
          [
            [:datastore,      "find", kind: "User"],
            [:auth,           "sign", auth: :direct],
            [:reset_password, "send-email", env: contents["reset-email"]],
          ]
        end
      end

      namespace :profile, auth: :api do
        api :update do
          [
            [:auth, "password-hash", kind: "User"],
            [:datastore, "modify", scope: [
              [
                "User",
                action: :replace,
                samekey: "loginID",
                cols: ["email","loginID","password"],
              ],
            ]],
          ]
        end
      end
    end

    assert_equal(
      {
        "/getto/habit/token/auth" => {
          origin: "http://localhost:12080",
          commands: [
            "getto/flight-auth-phoenix:0.0.0-pre23 flight_auth format-for-auth User",
            "getto/flight-datastore-diplomat:0.0.0-pre14 flight_datastore find User",
            "getto/flight-auth-phoenix:0.0.0-pre23 flight_auth sign api.habit.getto.systems"
          ]
        },
        "/getto/habit/token/direct" => {
          origin: "http://localhost:12080",
          auth: {
            method: "header",
            expire: 600,
            verify: 600,
            image: "getto/flight-auth-phoenix:0.0.0-pre23",
            key: "direct.habit.getto.systems",
          },
          commands: [
            "getto/flight-auth-phoenix:0.0.0-pre23 flight_auth renew api.habit.getto.systems --verify 600"
          ]
        },
        "/getto/habit/token/renew" => {
          origin: "http://localhost:12080",
          auth: {
            method: "header",
            expire: 604800,
            verify: 1209600,
            image: "getto/flight-auth-phoenix:0.0.0-pre23",
            key: "api.habit.getto.systems",
          },
          commands: [
            "getto/flight-auth-phoenix:0.0.0-pre23 flight_auth renew api.habit.getto.systems --verify 1209600"
          ]
        },
        "/getto/habit/token/reset" => {
          origin: "http://localhost:12080",
          commands: [
            "getto/flight-datastore-diplomat:0.0.0-pre14 flight_datastore find User",
            "getto/flight-auth-phoenix:0.0.0-pre23 flight_auth sign direct.habit.getto.systems",
            "getto/flight-reset_password-phoenix:0.0.0-pre6 flight_reset_password send-email "
          ]
        },
        "/getto/habit/profile/update" => {
          origin: "http://localhost:12080",
          auth: {
            method: "header",
            expire: 604800,
            verify: 1209600,
            image: "getto/flight-auth-phoenix:0.0.0-pre23",
            key: "api.habit.getto.systems",
          },
          commands: [
            "getto/flight-auth-phoenix:0.0.0-pre23 flight_auth password-hash User User",
            "getto/flight-datastore-diplomat:0.0.0-pre14 flight_datastore modify User:replace:samekey\\=loginID:cols\\=email,loginID,password"
          ]
        }
      },
      config,
      "build"
    )

    assert_equal 'GCP_CREDENTIALS_JSON="JSON"', File.read(File.expand_path("../routes/getto/habit/token/auth/2.env",__FILE__)), "env"
    assert_equal 'SMTP_SERVER=SMTP-SERVER
SMTP_PORT=SMTP-PORT
SMTP_USER=SMTP-USER
SMTP_PASSWORD=SMTP-PASSWORD
LOGIN_URL=http://localhost:12080/login/direct.html
EMAIL_FROM=EMAIL-FROM
EMAIL_SUBJECT=EMAIL-SUBJECT
EMAIL_BODY=EMAIL\\nBODY\\n', File.read(File.expand_path("../routes/getto/habit/token/reset/3.env",__FILE__)), "env"
  end
end
