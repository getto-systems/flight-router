require "test_helper"

class Flight::RouterTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Flight::Router::VERSION
  end
end
