require 'sinatra'
require 'data_mapper'
require 'json'
require 'rack/contrib'
require 'twilio-ruby'

DataMapper.setup(:default, 'postgres://postgres:postgres@localhost/marketing_notifications')

class Subscriber
  include DataMapper::Resource 

  property :id, Serial
  property :phone_number, String
  property :subscribed, Boolean

  def send_message(message, image_url)
    @twilio_number = ENV['TWILIO_PHONE_NUMBER']
    @client = Twilio::REST::Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']
    message = @client.account.messages.create(
      :from => @twilio_number,
      :to => "+5581994596094",
      :body => message,
      :media_url => image_url
    )       
    puts message.to  
  end

end

DataMapper.finalize

Subscriber.auto_upgrade!

use ::Rack::PostBodyContentTypeParser

get '/' do
  erb :index, locals: {message: nil}
end

post '/messages' do
  Subscriber.all.each do |subscriber|
    subscriber.send_message(params['message'], params['image_url'])
  end

  erb :index, locals: {message: 'Messages Sent!!!'}
end

post '/subscriber' do
  if is_valid(params[:Body])
    subscriber = create_or_update_subscriber(params)
    subscription_message = 'You are now subscribed for updates.'
    unsubscritpion_message = "You have unsubscribed from notifications. Test 'add' to start receieving updates again"
    subscriber.subscribed ? format_message(subscription_message) : format_message(unsubscritpion_message)
  else
    format_message("Thanks for contacting TWBC! Text 'add' if you would to receive updates via text message.")
  end
end

def is_subscription(command)
  command == 'add'
end

def is_valid(command)
  command == 'add' or command == 'remove'
end

def format_message(message)
  response = Twilio::TwiML::Response.new do |r|
    r.Message message
  end
  response.text
end

def create_or_update_subscriber(params)
  subscriber = Subscriber.first(:phone_number => params[:From])
  if subscriber
    subscriber.update(:subscribed => is_subscription(params[:Body]))
    subscriber
  else
    Subscriber.create(:phone_number => params[:From], :subscribed => is_subscription(params[:Body]))
  end
end
