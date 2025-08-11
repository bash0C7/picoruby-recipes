# -*- encoding: utf-8 -*-
# stub: ruby-termios 1.1.0 ruby lib
# stub: ext/extconf.rb

Gem::Specification.new do |s|
  s.name = "ruby-termios".freeze
  s.version = "1.1.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/arika/ruby-termios/issues", "homepage_uri" => "https://github.com/arika/ruby-termios", "source_code_ri" => "https://github.com/arika/ruby-termios" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["akira yamada".freeze]
  s.bindir = "exe".freeze
  s.date = "2020-12-15"
  s.description = "    Termios module is simple wrapper of termios(3).\n    It can be included into IO-family classes and can extend IO-family objects.\n    In addition, the methods can use as module function.\n".freeze
  s.email = ["akira@arika.org".freeze]
  s.extensions = ["ext/extconf.rb".freeze]
  s.files = ["ext/extconf.rb".freeze]
  s.homepage = "https://github.com/arika/ruby-termios".freeze
  s.licenses = ["Ruby's".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.3.0".freeze)
  s.rubygems_version = "3.2.0".freeze
  s.summary = "a simple wrapper of termios(3)".freeze

  s.installed_by_version = "3.6.9".freeze
end
