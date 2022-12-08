# axl411.github.io

My blog.

# Dev

## Setup:

```
brew install rbenv
rbenv init # then follow the steps to setup rbenv

gem install bundler
bundle install
```

## Update Ruby

```
# list latest stable versions:
rbenv install -l

# list all local versions:
rbenv install -L

# install a Ruby version:
rbenv install 3.1.2

# choose Ruby version 3.1.2:
rbenv local 3.1.2
```

## Update jekyll
```
make update
```

## Writing blogs
```
make start

make build
```
