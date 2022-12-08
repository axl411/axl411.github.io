update: # update jekyll version
	gem install bundler
	bundle install
	bundle update

start:
	bundle exec jekyll serve

build:
	bundle exec jekyll build
