class ConnectionManager::Connection
  class TimeoutError < StandardError; end

  attr_reader :connection, :metadata

  def initialize(connection, **options)
    @connection = connection
    @closed = false
    @close_method = options.fetch(:close_method, :close)
    @metadata = options[:metadata]
    @mutex = Mutex.new
    @timeout = options.fetch(:timeout, 0)
  end

  def close
    return false unless connection.respond_to?(@close_method)
    connection.public_send(@close_method)
    @closed = true
  end

  def closed?
    @closed
  end

  def synchronize(**options, &block)
    timeout = options.fetch(:timeout, @timeout)
    Timeout.timeout(timeout, TimeoutError) do
      mutex.synchronize { block.call }
    end
  end

  private

  attr_reader :mutex
end
