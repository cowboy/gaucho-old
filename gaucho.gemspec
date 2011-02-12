$:.push File.expand_path('../lib', __FILE__)
require 'gaucho/version'

Gem::Specification.new do |s|
  # Note to self:
  # http://docs.rubygems.org/read/chapter/20
  # http://rubygems.rubyforge.org/rubygems-update/Gem/Specification.html

  s.name              = 'gaucho'
  s.rubyforge_project = 'gaucho'
  s.version           = Gaucho::VERSION
  s.authors           = ['Ben Alman']
  s.email             = 'cowboy@rj3.net'
  s.homepage          = 'http://github.com/cowboy/gaucho'
  s.license           = %w{MIT GPL-2}
  s.summary           = %Q{Ruby + Git + Content = Gaucho}
  s.description       = %Q{Explain what "Ruby + Git + Content = Gaucho" means}

  s.required_ruby_version = '>= 1.9.2'

  s.add_dependency 'grit', '>= 2.4.1'
  s.add_dependency 'rdiscount', '>= 1.6.5'
  s.add_dependency 'unicode_utils', '>= 1.0.0'

  s.add_development_dependency 'shoulda', '>= 0'
  s.add_development_dependency 'bundler', '~> 1.0.0'
  s.add_development_dependency 'rcov', '>= 0'

  s.rdoc_options      = ['--charset=UTF-8']
  s.extra_rdoc_files  = %w{README.md LICENSE-MIT LICENSE-GPL}

  s.files             = `git ls-files`.split("\n")
  s.test_files        = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths     = %w{lib}
end
