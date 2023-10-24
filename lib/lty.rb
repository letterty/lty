# frozen_string_literal: true

require 'nokogiri'
require 'pragmatic_segmenter'

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

  LEGAL_KINDS = Set.new(%w[header paragraph quote]).freeze

  class Paragraph
    attr_accessor :kind,
                  :sentences

    def initialize(xml)
      @xml = xml
      self.sentences = []

      if (kind_attr = xml.attribute('kind'))
        kind = kind_attr.value
        fail "Unknown kind: #{kind.inspect}" unless LEGAL_KINDS.include?(kind)
        self.kind = kind
      end

      paragraph_flat = xml.to_s
      flat_sentences = self.class.text_paragraph_to_sentences(paragraph_flat)
      current_sentence_idx = 0
      current_sentence_part = ''
      text_links = []

      xml.children.each do |node|
        current_sentence = flat_sentences[current_sentence_idx]

        case node.node_type
          when Nokogiri::XML::Node::TEXT_NODE
            if node.text == current_sentence
              text_links << TextLink.new(node.text)
              current_sentence_part += node.text.dup
            else # multiple sentences in text node
              node_sentences = self.class.text_paragraph_to_sentences(node.text)
              if node_sentences.empty? # something small
                text_links << TextLink.new(node.text)
                current_sentence_part += node.text.dup
              end

              node_sentences.each_with_index do |node_sentence, node_sentence_idx|
                if node_sentence == current_sentence
                  text_links << TextLink.new(node_sentence)

                  self.sentences << Sentence.new(text_links)
                  current_sentence_idx += 1
                  current_sentence_part = ''
                  current_sentence = flat_sentences[current_sentence_idx]
                  text_links = []
                elsif node_sentence_idx == 0
                  text_links << TextLink.new(node.text)
                  current_sentence_part += node.text.dup
                else
                  parsed_pos = node_sentences[0..node_sentence_idx - 1].map(&:length).sum + 1
                  node_sentence_chunk = node.text[parsed_pos..-1]
                  if current_sentence_part == ''
                    node_sentence_chunk.lstrip! # Remove spaces from the beginning
                  end
                  current_sentence_part += node_sentence_chunk.dup
                  text_links << TextLink.new(node_sentence_chunk)
                end
              end
            end
          when Nokogiri::XML::Node::ELEMENT_NODE
            if node.name == 'link'
              text_links << TextLink.new(node.text, node['url'])
              current_sentence_part += node.text.dup
            else
              fail "Unsupported node name: #{node.name.inspect}"
            end
          else
            fail "Unsupported node type: #{node.node_type.inspect}"
        end

        if current_sentence && (current_sentence_part.length > current_sentence.length) # likely trailing spaces
          current_sentence_part.rstrip!
          if current_sentence_part.length > current_sentence.length # if still too long, then no luck
            fail "I think I'm lost comparing #{current_sentence_part.inspect} with #{current_sentence.inspect}"
          end
        end

        if (current_sentence_part != '') && (current_sentence_part == current_sentence)
          self.sentences << Sentence.new(text_links)
          current_sentence_idx += 1
          current_sentence_part = ''
          text_links = []
        end
      end
    end

    def to_h
      hash = {
        sentences: self.sentences.map(&:to_h)
      }

      hash[:kind] = self.kind if self.kind

      hash
    end

    def self.text_paragraph_to_sentences(text_paragraph, clean: true)
      ps = PragmaticSegmenter::Segmenter.new(text: text_paragraph, clean: clean)
      return ps.segment
    end
  end

  class Sentence
    attr_accessor :text_links

    def initialize(text_links)
      @text_links = text_links
    end

    def ==(other)
      self.text_links == other.text_links
    end

    def to_h
      {
        text_links: self.text_links.map(&:to_h)
      }
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
