require "json"
require "base64"

module Flight::Router
  class Container
    module Builder
      def self.image(image,&block)
        @image = image
        block.call
        @image = nil
      end
      def self.command(command,&block)
        builder[@image] ||= {}
        builder[@image][command] = block
      end
      def self.builder
        @builder ||= {}
      end

      image :auth do
        command "format-for-auth" do |kind:|
          [kind]
        end
        command "password-hash" do |kind:|
          [kind, kind]
        end
        command "sign" do |auth:|
          [map[:auth][auth][:key]]
        end
        command "renew" do |auth:,verify:|
          [map[:auth][auth][:key], "--verify", map[:auth][verify][:verify]]
        end
      end

      image :datastore do
        command "find" do |kind:,scope:|
          scope = Base64.strict_encode64(JSON.generate(scope))
          [kind, scope]
        end
        command "modify" do |scope:|
          scope = Base64.strict_encode64(JSON.generate(scope))
          [scope]
        end
      end

      image :reset_password do
        command "send-email" do
          []
        end
      end
    end

    using HashEx

    def initialize(path,app:,map:,output_dir:)
      @path = path
      @app = app
      @map = map
      @output_dir = output_dir
      @builder = Builder.builder
    end

    def map
      @map
    end

    def config
      @config ||= {}
    end

    def namespace(path,auth: nil,&block)
      @path << path

      _app = @app
      app = {}
      merge_auth(app,auth)
      @app = @app.dup.deep_merge(app)

      _config = config
      @config = {}

      instance_exec(&block)

      @app = _app
      @config = _config.merge(@config)
      @path.pop
    end
    def api(path,auth: nil,&block)
      path = @path + [path]
      config = {}
      merge_auth(config,auth)
      commands = parse_command path, instance_exec(&block)
      @config[path.join("/")] = @app
        .deep_merge(config)
        .deep_merge(commands: commands)
    end

    private

      def merge_auth(hash,auth)
        if auth
          hash[:auth] = map[:auth][auth]
        end
      end

      def parse_command(path,commands)
        commands.each.with_index(1).map{|(image,key,opts),i|
          unless info = map[:image][image]
            raise "image not defined: [#{image}]"
          end
          if opts[:env] || info[:env]
            puts_env(path, "#{i}.env", (info[:env] || {}).merge(opts[:env] || {}))
          end
          if block = @builder[image][key]
            command_args = instance_exec(**opts,&block)
          else
            raise "unknown image/key pair: #{image}/#{key}"
          end
          "#{info[:name]} flight_#{image} #{key} #{command_args.join(" ")}"
        }
      end

      def puts_env(path,file,env)
        dir = File.join(@output_dir.to_s,path.map(&:to_s))
        FileUtils.mkdir_p(dir)
        File.write(File.join(dir,file),env.map{|k,v|
          v = case v
          when String
            v
          else
            JSON.generate(v)
          end
          "#{k}=#{v}"
        }.join("\n"))
      end
  end
end
