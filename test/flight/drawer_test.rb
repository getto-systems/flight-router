require "test_helper"
require "json"

class Flight::DrawerTest < Minitest::Test
  def test_draw
    router = Flight::Router::Drawer.new(
      project: "getto/habit",
      env: "development",
      output_dir: File.expand_path("../routes",__FILE__),
      input_dir: File.expand_path("../projects",__FILE__),
    )
    router.map do
      set :credentials, load_yaml("credentials/#{env}.yml")
      set :contents, load_yaml("contents.yml")

      set :domain, "habit.getto.systems"
      set :bucket, {
        upload: "uploads.#{map[:domain]}"
      }
      set :origin, env(
        production:  "https://#{map[:domain]}",
        development: "http://localhost:12080",
      )

      group :image do
        set :auth,           "phoenix",  "0.0.0-pre23"
        set :datastore,      "diplomat", "0.0.0-pre14", env: map[:credentials]["gcp"]
        set :reset_password, "phoenix",  "0.0.0-pre6",  env: map[:credentials]["smtp"]
        set :aws_s3,         "s3cmd",    "0.0.0-pre10", env: map[:credentials]["s3"]
        set :excel,          "roo",      "0.0.0-pre0"
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

    config = router.build do
      namespace :token do
        api :auth do
          cmd :auth,      "format-for-auth", namespace: "Namespace", kind: "User"
          cmd :datastore, "find", kind: "User", scope: {}
          cmd :auth,      "sign", auth: :api
        end
        api :direct, auth: :direct do
          cmd :auth, "renew", auth: :api, verify: :direct
        end
        api :renew, auth: :api do
          cmd :auth, "renew", auth: :api, verify: :api
        end
        api :reset do
          cmd :datastore,      "find", kind: "User", scope: {}
          cmd :auth,           "sign", auth: :direct
          cmd :reset_password, "send-email", env: map[:contents]["reset-email"].tap{|email|
            email["EMAIL"].merge!(
              login_url: "#{map[:origin]}/login/direct.html",
            )
          }
        end
      end

      namespace :profile, auth: :api do
        api :update do
          cmd :auth, "password-hash", kind: "User"
          cmd :datastore, "modify", scope: {
            User: {
              replace: {
                samekey: "loginID",
                cols: ["email","loginID","password"],
              },
            },
          }
        end
        api :upload, upload: {kind: "File", dest: :upload, bucket: map[:bucket][:upload]} do
          header = map[:contents]["excel"]["header"]
          fill = [
            #{kind: "Supplier", column: "supplier_code", cols: [:name]},
          ]

          cmd :datastore, "upload"

          cmd :excel, "read",            src: :upload, dest: :raw,  sheet: "Sheet1", header: header
          cmd :datastore, "bulk-insert", src: :raw,    dest: :data, keys: [:catalog_number], fill: fill
          #cmd :bigquery, "load",         src: :data

          cmd :aws_s3, "copy", path: [:original,:raw,:data]
        end
      end
    end

    assert_equal(
      {
        "/getto/habit/token/auth" => {
          origin: "http://localhost:12080",
          commands: [
            {image: "getto/flight-auth-phoenix:0.0.0-pre23", command: ["flight_auth","format-for-auth",JSON.generate(namespace: "Namespace", salt: "User")]},
            {image: "getto/flight-datastore-diplomat:0.0.0-pre14", command: ["flight_datastore","find",JSON.generate(kind: "User", scope: {})]},
            {image: "getto/flight-auth-phoenix:0.0.0-pre23", command: ["flight_auth","sign",JSON.generate(key: "api.habit.getto.systems")]},
          ],
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
            {image: "getto/flight-auth-phoenix:0.0.0-pre23", command: ["flight_auth","renew",JSON.generate(key: "api.habit.getto.systems",verify: 600)]},
          ],
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
            {image: "getto/flight-auth-phoenix:0.0.0-pre23", command: ["flight_auth","renew",JSON.generate(key: "api.habit.getto.systems",verify: 1209600)]},
          ],
        },
        "/getto/habit/token/reset" => {
          origin: "http://localhost:12080",
          commands: [
            {image: "getto/flight-datastore-diplomat:0.0.0-pre14", command: ["flight_datastore","find",JSON.generate(kind: "User", scope: {})]},
            {image: "getto/flight-auth-phoenix:0.0.0-pre23", command: ["flight_auth","sign",JSON.generate(key: "direct.habit.getto.systems")]},
            {image: "getto/flight-reset_password-phoenix:0.0.0-pre6", command: ["flight_reset_password","send-email",JSON.generate({})]},
          ],
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
            {image: "getto/flight-auth-phoenix:0.0.0-pre23", command: ["flight_auth","password-hash",JSON.generate(kind: "User",salt: "User")]},
            {image: "getto/flight-datastore-diplomat:0.0.0-pre14", command: ["flight_datastore","modify",JSON.generate(scope: {
              User: {
                replace: {
                  samekey: "loginID",
                  cols: ["email","loginID","password"],
                },
              },
            })]},
          ],
        },
        "/getto/habit/profile/upload" => {
          origin: "http://localhost:12080",
          auth: {
            method: "header",
            expire: 604800,
            verify: 1209600,
            image: "getto/flight-auth-phoenix:0.0.0-pre23",
            key: "api.habit.getto.systems",
          },
          upload: {
            kind: "File",
            dest: :upload,
            bucket: "uploads.habit.getto.systems",
          },
          commands: [
            {image: "getto/flight-datastore-diplomat:0.0.0-pre14", command: ["flight_datastore","upload",JSON.generate({})]},
            {image: "getto/flight-excel-roo:0.0.0-pre0", command: ["flight_excel","read",JSON.generate(src: :upload,dest: :raw, sheet: "Sheet1", header: {"column1" => "カラム1", "column2" => "カラム2"})]},
            {image: "getto/flight-datastore-diplomat:0.0.0-pre14", command: ["flight_datastore","bulk-insert",JSON.generate(src: :raw, dest: :data, keys: [:catalog_number], fill: [])]},
            {image: "getto/flight-aws_s3-s3cmd:0.0.0-pre10", command: ["flight_aws_s3","copy",JSON.generate(path: [:original,:raw,:data])]},
          ],
        },
      },
      config,
      "build"
    )

    assert_equal 'GCP_CREDENTIALS_JSON="JSON"', File.read(File.expand_path("../routes/getto/habit/token/auth/2.env",__FILE__)), "env"
    assert_equal 'SMTP={"server":"SMTP-SERVER","port":"SMTP-PORT","user":"SMTP-USER","password":"SMTP-PASSWORD"}
EMAIL={"from":"EMAIL-FROM","subject":"EMAIL-SUBJECT","body":"EMAIL\\nBODY\\n","login_url":"http://localhost:12080/login/direct.html"}', File.read(File.expand_path("../routes/getto/habit/token/reset/3.env",__FILE__)), "env"
  end
end
