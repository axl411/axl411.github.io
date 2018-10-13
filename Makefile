update:
	gem install bundler
	bundle install
	bundle exec bundle update

start:
	bundle exec jekyll serve

build:
	bundle exec jekyll build