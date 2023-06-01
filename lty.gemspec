# frozen_string_literal: true

require_relative "lib/lty/version"

Gem::Specification.new do |spec|
  spec.name = "lty"
  spec.version = Lty::VERSION
  spec.authors = ["Artur Pyrogovskyi"]
  spec.email = ["arp@letterty.com"]

  spec.summary = "Letterty's .lty document format parser and importer"
  spec.description = "Letterty uses an internal file format .lty to represent its articles.\n"\
    "Files in this format can be imported directly into the platform."
  spec.homepage = "https://letterty.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/letterty/lty"
  spec.metadata["changelog_uri"] = "https://github.com/letterty/lty/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) {
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  }
  spec.bindir = "bin"
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "nokogiri", "~> 1.15"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
