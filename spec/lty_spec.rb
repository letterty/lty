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
        expect(body.paragraphs[0].content).to eq('Where are the birds? They are flying.')
        expect(body.paragraphs[0].kind).to be_nil

        expect(body.paragraphs[1].content).to eq('I know the names of the birds. Maybe?')
        expect(body.paragraphs[1].kind).to eq('header')

        expect(body.paragraphs[2].content).to eq('Flying high in the sky, it\'s blue as far as your eyes can see.')
        expect(body.paragraphs[2].kind).to eq('quote')

        expect(body.paragraphs[3].content).to eq('And it\'s also fun, of course.')
      end
    end
  end
end
