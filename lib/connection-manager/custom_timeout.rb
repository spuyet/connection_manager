module ConnectionManager::CustomTimeout
  def with_custom_timeout(timeout, mutex, error_klass, &block)
    current = Thread.current
    timer = Thread.new do
      sleep timeout
      current.raise error_klass.new
    end
    mutex.synchronize do
      timer.kill
      block.call
    end
  end
end
