class Api::FeedbacksController < ApplicationController
  respond_to :json
  after_filter :cors_set_access_control_headers
  skip_before_filter :verify_authenticity_token

  def cors_set_access_control_headers
    headers['Access-Control-Allow-Origin'] = '*'
  end

  # POST /feedbacks
  # POST /feedbacks.json
  def create
    @feedback = Feedback.new(feedback_params)
    return respond_with(@feedback, location: nil)
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def feedback_params
    params.permit(:message)
  end
end
