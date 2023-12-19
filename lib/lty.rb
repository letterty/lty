# frozen_string_literal: true

require 'nokogiri'
require 'pragmatic_segmenter'

require_relative "lty/version"

module Lty
  class Error < StandardError; end

  LANGUAGE_MODEL = PragmaticSegmenter::Languages.get_language_by_code('en') # English hardcoded for now
  CONFIG = {
    segmenter: lambda { |paragraph_text|
      cleaned_text_paragraph =
        LANGUAGE_MODEL::Cleaner.new(text: paragraph_text, language: LANGUAGE_MODEL)
          .send(:check_for_no_space_in_between_sentences)

      ps = PragmaticSegmenter::Segmenter.new(text: cleaned_text_paragraph, clean: false)

      return ps.segment
    }
  }

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

      title = xml.at('title')
      self.title = title.text if title

      lead = xml.at('lead')
      self.lead = lead.text if lead
    end
  end

  class Body
    attr_accessor :paragraphs

    def initialize(xml)
      @xml = xml

      self.paragraphs = xml.xpath('bl').map { |pxml|
        Paragraph.new(pxml)
      }
    end
  end

  LEGAL_KINDS = Set.new(%w[header paragraph quote]).freeze

  class Paragraph
    attr_accessor :kind,
                  :level, # and this makes me feel they should be different nodes (p, header) in the end :P
                  :sentences

    def initialize(xml)
      @xml = xml
      self.sentences = []

      if (kind_attr = xml.attribute('kind'))
        kind = kind_attr.value
        fail "Unknown kind: #{kind.inspect}" unless LEGAL_KINDS.include?(kind)
        self.kind = kind
      end

      if (level_attr = xml.attribute('level'))
        level = level_attr.value.to_i
        fail "Number should be within 1-6" unless level.between?(1, 6)
        self.level = level
      end

      paragraph_text = xml.children.to_s
      sentences = ::Lty::CONFIG[:segmenter].call(paragraph_text)

      sentences.each do |sentence|
        sxml = Nokogiri::XML("<x>#{sentence}</x>")

        text = sxml.text
        text_links = []

        sxml.at('//x').children.each do |node|
          case node.node_type
            when Nokogiri::XML::Node::TEXT_NODE
              text_links << TextLink.new(node.text) 
            when Nokogiri::XML::Node::ELEMENT_NODE
              if node.name == 'link'
                text_links << TextLink.new(node.text, node['url']) 
              else
                fail "Unsupported node name: #{node.name.inspect}"
              end
            else
              fail "Unsupported node type: #{node.node_type.inspect}"
          end
        end

        self.sentences << Sentence.new(text, text_links) unless text == ""
      end
    end

    def to_h
      hash = {
        sentences: self.sentences.map(&:to_h)
      }

      hash[:kind] = self.kind if self.kind
      hash[:level] = self.level if self.level

      hash
    end
  end

  class Sentence
    attr_accessor :text,
                  :text_links

    def initialize(text, text_links)
      @text = text
      if (text_links.length > 0) &&
          text_links.map(&:link).any?
        @text_links = text_links
      end
    end

    def ==(other)
      (self.text == other.text) &&
        (self.text_links == other.text_links)
    end

    def to_h
      hash = {
        text: self.text
      }

      if self.text_links
        hash[:text_links] = self.text_links.map(&:to_h) 
      end

      hash
    end
  end

  class TextLink
    attr_accessor :text,
                  :link

    def initialize(text, link = nil)
      @text = text
      @link = link
    end

    def ==(other)
      (self.text == other.text) &&
        (self.link == other.link)
    end

    def to_h
      hash = {
        text: self.text
      }

      hash[:link] = self.link if self.link

      return hash
    end
  end
end
