# frozen_string_literal: true

require 'nokogiri'
require_relative "lty/version"

module Lty
  class Error < StandardError; end

  class Article
    attr_accessor :head,
                  :body

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

    def self.from_text(text)
      xml = Nokogiri::XML(text)

      return self.new(xml)
    end
  end

  class Head
    attr_accessor :title,
                  :lead

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

      self.paragraphs = xml.xpath('b').map { |pxml|
        Paragraph.new(pxml)
      }
    end
  end

  class Link
    attr_accessor :from,
                  :to,
                  :url

    def initialize(from:, to:, url:)
      @from = from
      @to = to
      @url = url
    end
    
    def ==(other)
      (self.from == other.from) &&
        (self.to == other.to) &&
        (self.url == other.url)
    end

    def to_h
      {
        from: from,
        to: to,
        url: url
      }
    end
  end

  LEGAL_KINDS = Set.new(%w[header paragraph quote]).freeze

  class Paragraph
    attr_accessor :content,
                  :kind,
                  :links

    def initialize(xml)
      @xml = xml

      if (kind_attr = xml.attribute('kind'))
        kind = kind_attr.value
        fail "Unknown kind: #{kind.inspect}" unless LEGAL_KINDS.include?(kind)
        self.kind = kind
      end

      # Initialize an empty array to store link data for this block
      self.links = []

      # Initialize a cursor to keep track of the character position within the text
      cursor = 0

      # This will hold the final text for this block, with the anchor tags removed
      self.content = ''

      xml.children.each do |node|
        if node.node_type == Nokogiri::XML::Node::TEXT_NODE
          # If it's a text node, just append its text to the final output
          self.content += node.text
          cursor += node.text.length
        elsif node.node_type == Nokogiri::XML::Node::ELEMENT_NODE && node.name == 'link'
          # If it's a link tag, record its position, text, and href
          start_pos = cursor
          link_text = node.text
          end_pos = start_pos + link_text.length

          # Append the link text to the final output
          self.content += link_text

          # Record the link data
          links << Link.new(
            from: start_pos,
            to: end_pos,
            url: node['url']
          )

          # Move the cursor to the end of the link text
          cursor = end_pos
        else
          fail "Unsupported node #{node.inspect}"
        end
      end
    end
  end
end
