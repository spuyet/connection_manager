# ConnectionManager

[![Build Status](https://travis-ci.com/spuyet/connection_manager.svg?token=n5bcPpqTwxxsDsj9JB2x&branch=master)](https://travis-ci.com/spuyet/connection_manager)
[![Gem Version](https://badge.fury.io/rb/connection-manager.svg)](https://badge.fury.io/rb/connection-manager)

A gem to manage your persistent connections.

## Usage

Create a thread-safe connection manager:
```ruby
$manager = ConnectionManager.new(timeout: 5)
```

Push your connections at any time:
```ruby
$manager.push("redis") { Redis.new }
```

And use them according to your needs:
```ruby
$manager.with("redis") do |redis|
  redis.get("mykey")
end
```

A metadata store per connection is also available allowing you to create custom behavior:
```ruby
Thread.new do
  $manager.with("redis") do |redis, metadata|
    metadata[:last_used_at] = Time.now
    redis.get("mykey")
  end
end

Thread.new do
  metadata = $manager.metadata("redis")
  $manager.reset("redis") if metadata[:last_used_at] < 1.hour.ago
end
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/spuyet/connection_manager.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Author

Sébastien Puyet ([@spuyet](https://twitter.com/spuyet)): [sebastien@puyet.fr](mailto:sebastien@puyet.fr)
