module Flight::Router
  class MapBase
    using HashEx

    def map
      @_config || config
    end
    def config
      @config ||= {}
    end

    def group(path,&block)
      @path ||= []
      @path << path

      @_config = config
      @config = {}

      instance_exec(&block)

      @config = @_config.deep_merge(
        path => @config,
      )
      @_config = nil

      @path.pop
    end
    def set(key,*args,**opts)
      config[key] = value(key,args,opts)
    end

    private

      def value(key,args,opts)
        args.first
      end
  end
end
