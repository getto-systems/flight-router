module Flight::Router
  class Map < MapBase
    module Builder
      def self.build(*keys,&block)
        builder[keys] = block
      end
      def self.builder
        @builder ||= {}
      end

      build :image do |key,type,tag,**opts|
        opts.merge(
          name: "getto/flight-#{key}-#{type}:#{tag}",
        )
      end

      build :auth do |key,config|
        config.merge(
          image: map[:image][:auth][:name],
          key: "#{key}.#{map[:domain]}",
        )
      end
    end

    def initialize(env)
      @env = env.to_sym
      @builder = Builder.builder
    end

    def env(**opts)
      unless opts.has_key?(@env)
        raise "env not defined: [#{@env}]"
      end
      opts[@env]
    end

    private

      def value(key,args,opts)
        if block = @builder[@path]
          instance_exec(key,*args,**opts,&block)
        else
          super
        end
      end

  end
end
