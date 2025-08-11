# -*- encoding: utf-8 -*-
# stub: uart 1.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "uart".freeze
  s.version = "1.0.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Aaron Patterson".freeze]
  s.date = "2018-01-15"
  s.description = "UART is a simple wrapper around the ruby-termios gem that gives you an easy\ninterface for setting up a UART or serial connection.  This gem is written in\npure Ruby.  This gem relies on ruby-termios to provide bindings to the termios\nsystem call, but uses those bindings to set up a serial connection in pure Ruby.".freeze
  s.email = ["tenderlove@ruby-lang.org".freeze]
  s.extra_rdoc_files = ["Manifest.txt".freeze, "README.md".freeze]
  s.files = ["Manifest.txt".freeze, "README.md".freeze]
  s.homepage = "https://github.com/tenderlove/uart".freeze
  s.licenses = ["MIT".freeze]
  s.rdoc_options = ["--main".freeze, "README.md".freeze]
  s.rubygems_version = "2.7.3".freeze
  s.summary = "UART is a simple wrapper around the ruby-termios gem that gives you an easy interface for setting up a UART or serial connection".freeze

  s.installed_by_version = "3.6.9".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<ruby-termios>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<minitest>.freeze, ["~> 5.11".freeze])
  s.add_development_dependency(%q<rdoc>.freeze, ["~> 4.0".freeze])
  s.add_development_dependency(%q<hoe>.freeze, ["~> 3.16".freeze])
end
