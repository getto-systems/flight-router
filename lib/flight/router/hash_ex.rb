module Flight::Router
  module HashEx
    refine Hash do
      def deep_merge(hash)
        unless hash.respond_to?(:map)
          hash
        else
          merge Hash[hash.map{|k,v|
            case self[k]
            when Hash
              v = self[k].deep_merge(v)
            end
            [k, v]
          }]
        end
      end
    end
  end
end
