class ConnectionManager::Connection
  attr_reader :timeout

  def initialize(connection, options)
    @connection = connection
    @closed = false
    @close_method = options(:close_method, :close)
    @timeout = options.fetch(:timeout, false)
  end

  def close
    return false unless connection.respond_to?(close_method)
    connection.public_send(close_method)
    closed = true
  end

  def closed?
    closed
  end
end
