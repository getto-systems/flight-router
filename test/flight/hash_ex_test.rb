require "test_helper"

class Flight::HashExTest < Minitest::Test
  using Flight::Router::HashEx

  def test_deep_merge
    assert_equal(
      {
        a: {
          b: :c,
          d: :e,
          f: {
            g: :h,
            i: :j,
          }
        },
        k: :l,
        m: :n,
      },
      {
        a: {
          b: :c,
          f: {
            g: :h,
          }
        },
        m: :n,
      }.deep_merge(
        a: {
          d: :e,
          f: {
            i: :j,
          }
        },
        k: :l,
        m: :n,
      ),
      "deep_merge"
    )
  end
end
