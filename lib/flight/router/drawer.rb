require "json"

module Flight::Router
  class Drawer
    def initialize(project:,output_dir:,input_dir:,env:)
      @project = project
      @output_dir = output_dir
      @input_dir = input_dir
      @map = Map.new(env: env.to_sym, input_dir: File.join(input_dir,project))
      @app = App.new(@map)
    end

    def map(&block)
      @map.instance_exec(&block)
    end
    def app(&block)
      @app.instance_exec(&block)
    end

    def draw(&block)
      dir = File.join(@output_dir,path)
      FileUtils.mkdir_p(dir)
      File.write File.join(dir,"routes.json"), JSON.generate(build(path,&block))
    end
    def build(&block)
      path = File.join("/", @project)
      container = Container.new([path], app: @app.config, map: @map.map, output_dir: @output_dir)
      container.instance_exec(&block)
      container.config
    end
  end
end
