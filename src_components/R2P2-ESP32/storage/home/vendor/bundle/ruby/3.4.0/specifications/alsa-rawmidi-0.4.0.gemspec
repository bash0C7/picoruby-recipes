# -*- encoding: utf-8 -*-
# stub: alsa-rawmidi 0.4.0 ruby lib

Gem::Specification.new do |s|
  s.name = "alsa-rawmidi".freeze
  s.version = "0.4.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Ari Russo".freeze]
  s.date = "2022-02-18"
  s.description = "Realtime MIDI IO with Ruby for Linux via the ALSA RawMIDI API.".freeze
  s.email = ["ari.russo@gmail.com".freeze]
  s.homepage = "http://github.com/arirusso/alsa-rawmidi".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.rubygems_version = "3.3.3".freeze
  s.summary = "Realtime MIDI IO with Ruby for Linux".freeze

  s.installed_by_version = "3.6.9".freeze

  s.specification_version = 4

  s.add_development_dependency(%q<rake>.freeze, ["~> 13.0".freeze, ">= 13.0.6".freeze])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.11".freeze, ">= 3.11.0".freeze])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 1.10".freeze, ">= 1.10.0".freeze])
  s.add_runtime_dependency(%q<ffi>.freeze, ["~> 1.15".freeze, ">= 1.15.5".freeze])
end
