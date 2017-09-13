require "json"

module Flight::Router
  class Drawer
    def initialize(opts)
      @output_dir = opts[:output_dir]
      @output_file = opts[:output_file]
      @map = Map.new(opts[:env])
      @app = App.new(@map)
    end

    def map(&block)
      @map.instance_exec(&block)
    end
    def app(&block)
      @app.instance_exec(&block)
    end

    def draw(path,&block)
      dir = File.join(@output_dir,path)
      FileUtils.mkdir_p(dir)
      File.write File.join(dir,"routes.json"), JSON.generate(build(path,&block))
    end
    def build(path,&block)
      if path == "/"
        path == ""
      end
      container = Container.new([path], app: @app.config, map: @map.map, output_dir: @output_dir)
      container.instance_exec(&block)
      container.config
    end
  end
end
