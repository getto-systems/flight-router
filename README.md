# flight-router

[![Build Status](https://travis-ci.org/getto-systems/flight-router.svg?branch=master)](https://travis-ci.org/getto-systems/flight-router)
[![Gem Version](https://badge.fury.io/rb/flight-router.svg)](https://badge.fury.io/rb/flight-router)

router script for flight

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'flight-router'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install flight-router

## Usage

```ruby
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

router.draw("/getto/habit") do
  namespace :token do
    api :auth do
      [
        [:auth,      "format-for-auth", kind: "User"],
        [:datastore, "find", kind: "User", scope: {}],
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
        [:datastore,      "find", kind: "User", scope: {}],
        [:auth,           "sign", auth: :direct],
        [:reset_password, "send-email", env: contents["reset-email"]],
      ]
    end
  end

  namespace :profile, auth: :api do
    api :update do
      [
        [:auth, "password-hash", kind: "User"],
        [:datastore, "modify", scope: {
          User: {
            replace: {
              samekey: "loginID",
              cols: ["email","loginID","password"],
            }
          },
        }],
      ]
    end
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/getto-systems/flight-router.
