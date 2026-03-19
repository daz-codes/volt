Rails.application.config.solid_queue.connects_to = { database: { writing: :queue, reading: :queue } } unless ENV["SECRET_KEY_BASE_DUMMY"]
