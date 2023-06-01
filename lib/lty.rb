# frozen_string_literal: true

require 'nokogiri'
require_relative "lty/version"

module Lty
  class Error < StandardError; end

  class Article
    attr_accessor :head
    attr_accessor :body

    def initialize(xml)
      @xml = xml

      self.head = Head.new(xml.at('//lty/head'))
      self.body = Body.new(xml.at('//lty/body'))
    end

    def self.import(path_to_lty)
      xml = File.open(path_to_lty) { |f|
        Nokogiri::XML(f)
      }

      return self.new(xml)
    end
  end

  class Head
    attr_accessor :title
    attr_accessor :lead

    def initialize(xml)
      @xml = xml

      self.title = xml.at('title').text
      self.lead  = xml.at('lead').text
    end
  end

  class Body
    attr_accessor :paragraphs

    def initialize(xml)
      @xml = xml

      self.paragraphs = xml.xpath('p').map { |pxml|
        Paragraph.new(pxml)
      }
    end
  end

  class Paragraph
    attr_accessor :content

    def initialize(xml)
      @xml = xml

      self.content = xml.text
    end
  end
end
