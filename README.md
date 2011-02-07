# Gaucho

Ruby + Git + Content = Gaucho

## Give it a whirl

Warning, this is a work in progress, so YMMV. Tested with Ruby 1.9.2p174 and Git 1.7.2.

Run this code in your shell (ignore any # comment lines):

    # clone the repo
    git clone https://cowboy@github.com/cowboy/gaucho.git
    
    # install bundler
    gem install bundler
    
    # build gem and install all dependencies
    cd gaucho
    rake install
    
    # build test content repo
    cd sample_app
    ruby create_test_repo.rb
    
    # install sample app gems
    gem install sinatra diffy
    
    # run sample app
    ruby app.rb

And then visit this page: <http://localhost:4567/>

## Copyright

Copyright (c) 2011 "Cowboy" Ben Alman  
Dual licensed under the MIT and GPL licenses.  
<http://benalman.com/about/license/>
