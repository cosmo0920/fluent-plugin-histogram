require 'helper'

class HistogramOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
  count_key      keys
  flush_interval 60s
  bin_num        100
  tag_prefix     histo
  input_tag_remove_prefix test.input
  ]

  def create_driver(conf = CONFIG, tag='test')
    Fluent::Test::OutputTestDriver.new(Fluent::HistogramOutput, tag).configure(conf)
  end

  def test_configure
    assert_raise(Fluent::ConfigError) {
      create_driver %[ bin_num 0]
    }
  end

  def test_small_increment
    bin_num = 100
    f = create_driver %[ bin_num #{bin_num}]
    f.instance.increment("test.input", "A")
    f.instance.increment("test.input", "B")
    zero = f.instance.zero_hist
    zero["A".hash % bin_num] += 1
    zero["B".hash % bin_num] += 1
    assert_equal({"test.input" => {:hist => zero, :sum => 2, :avg => 2/bin_num, :sd=>0}}, 
                 f.instance.flush)
  end

  def test_tag_add_remove
    f = create_driver(%[tag_prefix histo])
    f.instance.increment("test",  "A")
    flushed = f.instance.flush
    assert_equal("histo.test", flushed.keys.join(''))

    f = create_driver(%[
                      tag_prefix histo
                      input_tag_remove_prefix test])
    f.instance.increment("test", "A")
    flushed = f.instance.flush
    assert_equal("histo", flushed.keys.join(''))
  end

  def test_tagging
    f = create_driver(%[
                      tag_prefix histo
                      input_tag_remove_prefix test])
    data = {"test.input" => [1, 2, 3, 4, 5]}
    tagged = f.instance.tagging(data)
    assert_equal("histo.input", tagged.keys.join(''))
  end

  def test_increment_sum
    bin_num = 100
    f = create_driver %[ bin_num #{bin_num}]
    1000.times do |i|
      f.instance.increment("test.input", i.to_s)
    end
    flushed = f.instance.flush
    assert_equal(1000, flushed["test.input"][:sum])
    assert_equal(1000 / bin_num, flushed["test.input"][:avg])
  end

  def test_emit
    bin_num = 100
    f = create_driver(%[bin_num #{bin_num}])
    f.run do
      100.times do 
        f.emit({"keys" => ["A", "B", "C"]})
      end
    end
    flushed = f.instance.flush
    assert_equal(100*3, flushed["test"][:sum])
    assert_equal(100*3 / bin_num, flushed["test"][:avg])
  end

end
