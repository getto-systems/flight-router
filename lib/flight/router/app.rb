module Flight::Router
  class App < MapBase
    def initialize(map)
      @map = map
    end

    def map
      @map.map
    end
  end
end
