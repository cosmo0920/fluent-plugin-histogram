# -*- coding: utf-8 -*-

require 'fluent/mixin/config_placeholders'

module Fluent
  class HistogramOutput < Fluent::Output
    Fluent::Plugin.register_output('histogram', self)

    config_param :tag, :string, :default => nil
    config_param :tag_prefix, :string, :default => nil
    config_param :tag_suffix, :string, :default => nil
    config_param :input_tag_remove_prefix, :string, :default => nil
    config_param :flush_interval, :time, :default => 60
    config_param :count_key, :string, :default => 'keys'
    config_param :bin_num, :integer, :default => 100

    include Fluent::Mixin::ConfigPlaceholders

    attr_accessor :flush_interval
    attr_accessor :hists
    attr_accessor :zero_hist
    attr_accessor :remove_prefix_string

    ## fluentd output plugin's methods

    def initialize
      super
    end

    def configure(conf)
      super

      raise Fluent::ConfigError, "bin_num must be > 0" if @bin_num <= 0
      $log.warn %Q[too small "bin_num(=#{@bin_num})" may raise unexpected outcome] if @bin_num < 100

      @tag_prefix_string = @tag_prefix + '.' if @tag_prefix
      @tag_suffix_string = '.' + @tag_suffix if @tag_suffix
      if @input_tag_remove_prefix
        @remove_prefix_string = @input_tag_remove_prefix + '.'
        @remove_prefix_length = @remove_prefix_string.length
      end

      @zero_hist = [0] * @bin_num

      @hists = initialize_hists
      @mutex = Mutex.new

    end

    def start
      super
      @watcher = Thread.new(&method(:watch))
    end

    def watch
      @last_checked = Fluent::Engine.now
      while true
        sleep 0.5
        if Fluent::Engine.now - @last_checked >= @flush_interval
          now = Fluent::Engine.now
          flush_emit(now)
          @last_checked = now
        end
      end
    end

    def shutdown
      super
      @watcher.terminate
      @watcher.join
    end


    ## Histogram plugin's method

    def initialize_hists(tags=nil)
      hists = {}
      if tags
        tags.each do |tag|
          hists[tag] = @zero_hist.dup
        end
      end
      hists
    end

    def increment(tag, key)
      @mutex.synchronize {
        @hists[tag] ||= @zero_hist.dup
        id = key.hash % @bin_num
        @hists[tag][id] += 1
      }
    end

    def emit(tag, es, chain)
      chain.next

      es.each do |time, record|
         keys = record[@count_key]
         [keys].flatten.each {|k| increment(tag, k)}
      end
    end
    
    def tagging(flushed)
      tagged = {}
      tagged = Hash[ flushed.map do |tag, hist|
        if @tag 
          tag = @tag
        else
          if @input_tag_remove_prefix &&
            ( ( tag.start_with?(@remove_prefix_string) && 
               tag.length > @remove_prefix_length ) ||
               tag == @input_tag_remove_prefix)
            tag = tag[@input_tag_remove_prefix.length..-1]
            tag.gsub!(/^\.|\.$/, "")
          end
          if @tag_prefix 
            tag = @tag_prefix_string << tag
            tag.gsub!(/^\.|\.$/, "")
          end
          if @tag_suffix
            tag += @tag_suffix_string
            tag.gsub!(/^\.|\.$/, "")
          end
        end

        [tag, hist]
      end ]
      tagged
    end

    def generate_output(flushed)
      output = {}
      flushed.each do |tag, hist|
        output[tag] = {}
        sum = hist.inject(:+)
        avg = sum.to_f / hist.size
        sd = hist.instance_eval do
          sigmas = map { |n| (avg - n)**2 }
          Math.sqrt(sigmas.inject(:+) / size)
        end
        output[tag][:hist] = hist
        output[tag][:sum] = sum
        output[tag][:avg] = avg.to_i
        output[tag][:sd] = sd.to_i
      end
      output
    end

    def flush
      flushed, @hists = generate_output(@hists), initialize_hists(@hists.keys.dup)
      tagging(flushed)
    end

    def flush_emit(now)
      flushed = flush
      flushed.each do |tag, data|
        Fluent::Engine.emit(tag, now, data)
      end
    end

  end
end
