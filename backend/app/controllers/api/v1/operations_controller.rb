module Api
  module V1
    class OperationsController < ApplicationController
      def queue_health
        render json: { data: Operations::QueueHealthQuery.new.call }
      end
    end
  end
end
