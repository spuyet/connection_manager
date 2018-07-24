require_relative 'connection_manager/connection'

class ConnectionManager
  def initialize(**options)
    @manager_timeout = @options.fetch(:action_timeout, false)
    @connections = {}
    @mutex = Mutex.new
  end

  def clear
    execute do
      connections.delete_if { |_, connection| connection.closed? }
    end
  end

  def close(key)
    execute do
      connections[key].close
    end
  end

  def delete(key)
    execute do
      connections.delete(key.to_sym)
    end
    true
  end

  def empty?
    size == 0
  end

  def pop(key)
    execute do
      connections.delete(key.to_sym).connection
    end
  end

  def push(key, connection, **options)
    execute do
      connections[key.to_sym] = Connection.new(connection, options)
    end
    true
  end

  def shutdown
    execute do
      connections.map do |connection|
        Thread.new { connection.close }
      end.each(&:join)
    end
    true
  end

  def size
    execute do
      connections.keys.size
    end
  end

  def with(key, **options)
    connection = execute do
      connections[key].connection
    end
    timeout = options.fetch(:timeout, connection.timeout)
    if timeout
      Timeout.timeout(timeout) { yield(connection) }
    else
      yield(connection)
    end
  end

  private

  attr_reader :connections, :mutex, :manager_timeout

  def execute(&block)
    mutex.synchronize do
      if manager_timeout
        Timeout.timeout(manager_timeout) { block.call }
      else
        block.call
      end
    end
  end
end
