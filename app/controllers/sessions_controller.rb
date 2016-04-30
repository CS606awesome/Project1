class SessionsController < ApplicationController
def new
   @account =Account.new
  end
  def create
   @account = Account.find_by(email: params[:session][:email].downcase)
  #@account.authenticate('123456')
   if @account && @account.authenticate(params[:session][:password])
      log_in @account
      redirect_to profiles_path 
      #:id => @account.id
    else
    flash.now[:danger] = 'Wrong email/password combination!'  
    render 'new'
    end
  end
  
  def show
   
  end
  
  def destroy
    log_out
    redirect_to accounts_path
    flash[:success] = "You have logout successfully!"
  end
end
