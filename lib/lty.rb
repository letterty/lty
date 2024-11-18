# frozen_string_literal: true
# encoding: UTF-8

require 'nokogiri'
require 'pragmatic_segmenter'
require 'date_core'
require 'htmlentities'

require_relative "lty/version"

module Lty
  class Error < StandardError; end

  @coder = HTMLEntities.new

  def self.html_escape(html)
    @coder.encode(html, :basic, :hexadecimal).gsub("&#xa;", "\n")
  end

  def self.html_unescape(html)
    @coder.decode(html)
  end

  class SentenceSegmenter
    QUOTES = %w( " “ ” ’ )
    CLOSING_QUOTES = %w( ” ’ )

    def initialize()
      @lm = PragmaticSegmenter::Languages.get_language_by_code('en') # English hardcoded for now
    end

    def call(text, final = false)
      cleaner = @lm::Cleaner.new(text: text, language: @lm)
      cleaned_text_paragraph = cleaner.send(:check_for_no_space_in_between_sentences)
      ps = PragmaticSegmenter::Segmenter.new(text: cleaned_text_paragraph, clean: false)
      sentences = ps.segment

      if final
        return sentences
      end

      final_sentences = []

      # Double pass, because PragmaticSegmenter doesn't handle multiple sentences within quote marks
      sentences.each do |sentence|
        if QUOTES.include?(sentence[0])
          reparsed_sentences = self.call(::Lty.html_unescape(sentence)[1..-1], true)
          if reparsed_sentences.length > 1
            reparsed_sentences[0] = sentence[0] + reparsed_sentences[0]


            final_sentences += reparsed_sentences
          else
            final_sentences << sentence
          end
        else
          final_sentences << sentence
        end
      end

      if final_sentences.length > 1
        if QUOTES.include?(::Lty.html_unescape(final_sentences[-1]))
          final_sentences[-2] << final_sentences.delete_at(-1)
        end
      end

      final_sentences.each_with_index do |final_sentence, index|
        danger_sentence = ::Lty.html_unescape(final_sentence)
        if index > 0 &&
          (danger_sentence.length > 1) &&
          CLOSING_QUOTES.include?(danger_sentence[0]) &&
          (danger_sentence[1] == ' ')

          escaped_quote = ::Lty.html_escape(danger_sentence[0])
          final_sentences[index - 1] << escaped_quote
          final_sentences[index] = final_sentence[(1+escaped_quote.length)..-1]
        end
      end

      danger_text = ::Lty.html_unescape(text)
      if QUOTES.include?(danger_text[-1]) && !QUOTES.include?(::Lty.html_unescape(final_sentences[-1])[-1])
        final_sentences[-1] << ::Lty.html_escape(danger_text[-1])
      end

      return final_sentences
    end
  end

  CONFIG = {
    segmenter: SentenceSegmenter.new
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
                  :lead,
                  :front,
                  :source

    def initialize(xml)
      @xml = xml

      title = xml.at('title')
      self.title = title.text.strip if title

      lead = xml.at('lead')
      self.lead = lead.text.strip if lead

      front = xml.at('front')
      self.front = front.text.strip if front

      source_data = {}
      source = xml.at('source')

      if source
        source_data[:author] = source.attribute('author')&.value
        source_data[:image_url] = source.attribute('image_url')&.value
        source_data[:url] = source.attribute('url')&.value
        source_created_at = source.attribute('created_at')&.value
        source_data[:created_at] = source_created_at && DateTime.parse(source_created_at)
      end

      self.source = source_data
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

  LEGAL_KINDS = Set.new(%w[header paragraph quote image]).freeze

  class Paragraph
    attr_accessor :kind,
                  :level, # and this makes me feel they should be different nodes (p, header) in the end :P
                  :sentences,
                  :iid

    def initialize(xml)
      @xml = xml
      self.sentences = []

      if (kind_attr = xml.attribute('kind'))
        kind = kind_attr.value
        fail "Unknown kind: #{kind.inspect}" unless LEGAL_KINDS.include?(kind)
        self.kind = kind
      end

      if self.kind == 'image'
        self.iid = xml.attribute('iid').value
        fail "image requires iid" if self.iid.nil? || self.iid.empty?
      end

      if (level_attr = xml.attribute('level'))
        level = level_attr.value.to_i
        fail "Number should be within 1-6" unless level.between?(1, 6)
        self.level = level
      end

      multiline_text = xml.children.to_s
      paragraph_texts = multiline_text.split('<br/>')
      paragraph_texts.each_with_index do |paragraph_text, index|
        if index > 0
          self.sentences << Sentence.new("\n", [])
        end
        self.sentences += self.text_to_sentences(paragraph_text)
      end
    end

    def text_to_sentences(paragraph_text)
      sentences = ::Lty::CONFIG[:segmenter].call(paragraph_text)
      lty_sentences = []

      sentences.each do |sentence|
        sxml = Nokogiri::XML("<x>#{sentence}</x>")

        text = sxml.text
        text_links = []

        sxml.at('//x').children.each do |node|
          case node.node_type
          when Nokogiri::XML::Node::TEXT_NODE
            text_links << TextLink.new(node.text) 
          when Nokogiri::XML::Node::ELEMENT_NODE
            case node.name
            when 'link'
              text_links << TextLink.new(node.text, node['url']) 
            else
              fail "Unsupported node name: #{node.name.inspect}"
            end
          else
            fail "Unsupported node type: #{node.node_type.inspect}"
          end
        end

        lty_sentences << Sentence.new(text, text_links) unless text == ""
      end

      return lty_sentences
    end

    def to_h
      hash = {
        sentences: self.sentences.map(&:to_h)
      }

      hash[:kind] = self.kind if self.kind
      hash[:level] = self.level if self.level
      hash[:iid] = self.iid if self.iid

      hash
    end
  end

  class TextElement
    attr_accessor :text

    def initialize(text)
      @text = ::Lty.html_unescape(text)
    end
  end

  class Sentence < TextElement
    attr_accessor :text_links

    def initialize(text, text_links)
      super(text)
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

  class TextLink < TextElement
    attr_accessor :link

    def initialize(text, link = nil)
      super(text)
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
