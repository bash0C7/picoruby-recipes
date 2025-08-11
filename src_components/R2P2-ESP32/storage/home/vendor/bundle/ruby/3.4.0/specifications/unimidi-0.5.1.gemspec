# -*- encoding: utf-8 -*-
# stub: unimidi 0.5.1 ruby lib

Gem::Specification.new do |s|
  s.name = "unimidi".freeze
  s.version = "0.5.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.6".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Ari Russo".freeze]
  s.date = "2022-02-18"
  s.description = "Platform independent realtime MIDI input and output for Ruby".freeze
  s.email = ["ari.russo@gmail.com".freeze]
  s.homepage = "http://github.com/arirusso/unimidi".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.rubygems_version = "3.3.3".freeze
  s.summary = "Realtime MIDI IO for Ruby".freeze

  s.installed_by_version = "3.6.9".freeze

  s.specification_version = 4

  s.add_development_dependency(%q<rake>.freeze, ["~> 13.0".freeze, ">= 13.0.6".freeze])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.11".freeze, ">= 3.11.0".freeze])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 1.25".freeze, ">= 1.25.1".freeze])
  s.add_runtime_dependency(%q<alsa-rawmidi>.freeze, ["~> 0.4".freeze, ">= 0.4.0".freeze])
  s.add_runtime_dependency(%q<ffi-coremidi>.freeze, ["~> 0.5".freeze, ">= 0.5.1".freeze])
  s.add_runtime_dependency(%q<midi-jruby>.freeze, ["~> 0.2".freeze, ">= 0.2.0".freeze])
  s.add_runtime_dependency(%q<midi-winmm>.freeze, ["~> 0.1".freeze, ">= 0.1.10".freeze])
end
