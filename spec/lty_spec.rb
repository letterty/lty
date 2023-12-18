# frozen_string_literal: true

EXAMPLE_PATH = File.join(__dir__, 'fixtures/example.lty')

RSpec.describe Lty do
  it "has a version number" do
    expect(Lty::VERSION).not_to be nil
  end

  describe "importing" do
    let(:article) { Lty::Article.import(EXAMPLE_PATH) }

    describe "head" do
      let(:head) { article.head }

      it "parses title" do
        expect(head.title).to eq('How do we learn to fly?')
      end

      it "parses lead" do
        expect(head.lead).to eq('Being a bird is a difficult job. It starts with learning to fly.')
      end
    end

    describe "body" do
      let(:body) { article.body }

      it "parses paragraphs" do
        expect(body.paragraphs[0].to_h).to eq({
          sentences: [
            {
              text: "Where are the birds?"
            },
            {
              text: 'They are flying.'
            }
          ]
        })

        expect(body.paragraphs[1].to_h).to eq({
          kind: 'header',
          sentences: [
            {
              text: 'I know the names of the birds.'
            },
            {
              text: 'Maybe?'
            }
          ]
        })

        expect(body.paragraphs[2].to_h).to eq({
          kind: 'quote',
          sentences: [
            {
              text: 'Flying high in the sky, it\'s blue as far as your eyes can see.'
            },
          ]
        })

        expect(body.paragraphs[3].to_h).to eq({
          sentences: [
            {
              text: "And it's also fun, of course.",
              text_links: [
                {
                  text: "And it's "
                },
                {
                  text: "also fun",
                  link: "https://example.fun"
                },
                {
                  text: ", of "
                },
                {
                  text: "course",
                  link: "https://example.com"
                },
                {
                  text: '.'
                }
              ]
            }
          ]
        })

        expect(body.paragraphs[4].to_h).to eq({
          sentences: [
            {
              text: "No link."
            },
            {
              text: "No link again."
            },
            {
              text: "Some link.",
              text_links: [
                {
                  text: "Some "
                },
                {
                  text: "link",
                  link: "https://example.link"
                },
                {
                  text: '.'
                }
              ]
            },
            {
              text: "Full sentence as a link.",
              text_links: [
                {
                  text: "Full sentence as a link.",
                  link: "https://example.full"
                }
              ]
            }
          ]
        })

        expect(body.paragraphs[5].to_h).to eq({
          sentences: [
            {
              text: "Links, one, off.",
              text_links: [
                {
                  text: "Links, "
                },
                {
                  text: "one",
                  link: "https://example1.link"
                },
                {
                  text: ", "
                },
                {
                  text: "off",
                  link: "https://example2.link"
                },
                {
                  text: "."
                }
              ]
            }
          ]
        })

        expect(body.paragraphs[6].to_h).to eq({
          kind: "header",
          level: 2,
          sentences: [
            {
              text: "Level 2"
            }
          ]
        })

        expect(body.paragraphs[7].to_h).to eq({
          sentences: [
            {
              text: "Run-on sentences."
            },
            {
              text: "Like this."
            },
            {
              text: "12 Work."
            }
          ]
        })
      end
    end
  end
end
