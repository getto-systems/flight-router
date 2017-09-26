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
        command "format-for-auth" do |kind:,**opts|
          opts.merge(salt: kind)
        end
        command "password-hash" do |kind:,**opts|
          opts.merge(kind: kind, salt: kind)
        end
        command "sign" do |auth:|
          {key: map[:auth][auth][:key]}
        end
        command "renew" do |auth:,verify:|
          {key: map[:auth][auth][:key], verify: map[:auth][verify][:verify]}
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
    def app
      @app
    end
    def cmd(image,command,**opts)
      @cmd.push(
        image: image,
        command: command,
        opts: opts,
      )
    end

    def config
      @config ||= {}
    end

    def namespace(path,auth: nil,**opts,&block)
      @path << path

      _app = @app
      app = {}
      merge_auth!(app,auth)
      @app = @app.dup.deep_merge(app).deep_merge(opts)

      _config = config
      @config = {}

      instance_exec(&block)

      @app = _app
      @config = _config.merge(@config)
      @path.pop
    end
    def api(path,auth: nil,**opts,&block)
      path = @path + [path]
      config = {}
      merge_auth!(config,auth)

      _app = @app
      @app = @app.deep_merge(config).deep_merge(opts)
      @cmd = []
      instance_exec(&block)

      @config[path.join("/")] = @app.deep_merge(commands: parse_command(path, @cmd))

      @app = _app
    end

    private

      def merge_auth!(hash,auth)
        if auth
          hash[:auth] = map[:auth][auth]
        end
      end

      def parse_command(path,commands)
        commands.each.with_index(1).map{|cmd,i|
          image = cmd[:image]
          command = cmd[:command]
          opts = cmd[:opts]

          unless info = map[:image][image]
            raise "image not defined: [#{image}]"
          end
          env = opts.delete(:env)
          if env || info[:env]
            puts_env(path, "#{i}.env", (info[:env] || {}).merge(env || {}))
          end
          if block = @builder[image] && @builder[image][command]
            command_args = instance_exec(**opts,&block)
          else
            command_args = opts
          end

          {image: info[:name], command: ["flight_#{image}",command,JSON.generate(command_args)]}
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
