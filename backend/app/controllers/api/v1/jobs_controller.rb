module Api
  module V1
    class JobsController < ApplicationController
      def show
        render json: { data: Job.find(params[:id]).api_json }
      end
    end
  end
end
