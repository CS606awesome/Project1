class AccountsController < ApplicationController
  def index
   redirect_to action: 'new' 
   
  end
  
  def new
    @account = Account.new
  end
  
  def edit
      @account = Account.find params[:id]
  end
  
  def create
    @account = Account.new(account_params)
    @cellphone_number = @account.cellphone.gsub(/\D/, '')
    @homephone_number = @account.homephone.gsub(/\D/, '')
    if @cellphone_number.length == 10   #change homephone format to xxx-xxx-xxxx
        @account.cellphone = correct_phone_format(@cellphone_number)
    end
    
    if @homephone_number.length == 10   #change homephone format to xxx-xxx-xxxx
        @account.homephone = correct_phone_format(@homephone_number)
    end
    
   # @account.DOB = @account.DOB.to_s.gsub(/^(\d{2})-(\d{2})-(\d{4})/, '\3-\1-\2') #change DOB format to yyyy-mm-dd
     correct_DOB_format(@account)

    if @account.save
      redirect_to @account 
    else  
      flash.now[:danger] = 'Registration failed, some information is missing!'  
      render 'new'
    end  
  end
  
  def correct_phone_format(account)
      account = account.insert(3, '-').insert(7, '-')
  end

  #used to correct the format of input DOB since the front end is using jQuery ui
  def correct_DOB_format(account)
      if /^((0[1-9])|(1[0-2]))\/((0[1-9])|(1[0-9])|(2[0-9])|(3[0-1]))\/(\d{4})$/.match(account.DOB.to_s)
        account.DOB = "#{$9}-#{$1}-#{$4}"
      end
  end
  
  def correct_DOB_format_update(account)
     if /^((0[1-9])|(1[0-2]))\/((0[1-9])|(1[0-9])|(2[0-9])|(3[0-1]))\/(\d{4})$/.match(account[:DOB])
        account[:DOB] = "#{$9}-#{$1}-#{$4}"
     end
  end
  
  #render the login page
  def show
    flash[:success] = 'Congradulations!now go ahead and login'  
    @account = Account.new
  end
  

  
  def profiles 
      if logged_in 
        @account = Account.find(session[:id])
     
      else
      redirect_to login_path
      end
  end
  
  #submit application 
  def submit_application
      @account = Account.find(session[:id])

      #@account.application_form.interested_areas = params[:account][:application_form_attributes][:interested_areas].join(' ')
      if @account.update(:is_volunteering=>true) #&& @account.is_volunteering == false
       
        if @account.update(account_update_params)
          @account.update(:application_form_attributes =>{:available_time_end => params[:account][:application_form_attributes][:available_time_end],:available_time_begin => params[:account][:application_form_attributes][:available_time_begin],:signature => params[:account][:application_form_attributes][:signature],:interested_areas => params[:account][:application_form_attributes][:interested_areas].join(' ')})
          #@account.update_attributes(:application_form_attributes =>{:interested_areas => params[:account][:application_form_attributes][:interested_areas][0]})
          #@account.update(:application_form_attributes =>{:signature => params[:account][:application_form_attributes][:signature]})
          #@account.update(:application_form_attributes =>{:available_time_begin => params[:account][:application_form_attributes][:available_time_begin]})
          #@account.update(:application_form_attributes =>{:available_time_end => params[:account][:application_form_attributes][:available_time_end]})
          redirect_to viewapplication_path
        else
          flash[:danger] = @account.errors.full_messages;
          redirect_to application_path(:id => @account.id)
        end
      else
        redirect_to action: 'application'
      end
  end


  def destroyapplication
   @account = Account.find(session[:id])
   if @account.is_volunteering == true
    if @account.update_columns(:is_volunteering =>false) && @account.application_form.destroy

      flash[:success] = "Withdrawal succeeded!"

      redirect_to action: 'profiles'
    else
      flash[:danger] = "Withdrawal failed!"  
      redirect_to action: 'viewapplication'
    end
   else
    flash[:danger] = "You have not submitted your application yet!" 

    redirect_to action: 'viewapplication'
   end
  end


  def application
      
      if logged_in
      @account = Account.find(session[:id]) 
          if @account.status == nil|| @account.status==false
              #if rejected
              if @account.status ==false
              flash[:danger] = 'You were rejected by our administrator, we are sorry you can not be a volunteer this time.' 
              #haven't submit for background check 
              else           
              flash[:danger] = 'You have not be approved by our administrator yet, please submit and wait with patience.'
              end
              redirect_to profiles_path#(:id => @account.id)
          else
          @account.application_form ||= ApplicationForm.new 
          # if user is a criminal
           if @account.has_convictions == true   
            @account.criminal_application ||= CriminalApplication.new
           end  
           #if user is required by organization
           if @account.is_student == true
               @account.student_application ||= StudentApplication.new
           end
           ##if user's DOB is later than 18 years ago(younder than 18)
 
           if to_sec(@account.DOB) > 18.years.ago.to_i    
            @account.minor_application ||= MinorApplication.new   
           end


          end          
     
      else
      redirect_to login_path
      end
  end

  
  def viewapplication
    if session[:id]
      @account = Account.find(session[:id])

    else
      redirect_to login_path
    end
  end
  
  def update


     @account = Account.find(params[:id])
     @my_update_hash = account_update_params

     if @account.submit_bcheck == false||admin_logged_in
     
        if(params[:account][:is_former_worker] == "1") 
          @account.user_formerworker ||= UserFormerworker.new  
        else
          @account.user_formerworker ||= UserFormerworker.new 
          @account.update(:is_former_worker => "0")
          if params[:account].has_key?(:user_formerworker_attributes)
              @my_update_hash[:user_formerworker_attributes][:date_of_employment] = "1999-3-8"
              @my_update_hash[:user_formerworker_attributes][:reason_for_leaving] = "none" 
              @my_update_hash[:user_formerworker_attributes][:position_or_department] = "none"
          end
        end
        
        if(params[:account][:related_to_councilmember] == "1")
          if params[:account][:related_councilmember_attributes].nil?
            @account.related_councilmember ||= RelatedCouncilmember.new
          elsif params[:account][:related_councilmember_attributes][:name].nil?
            #flash[:notice] = 'Please check one CM'
            flash[:warning] = ["council memeber name is blank"];
            redirect_to profiles_path  and return #:id => @account.id
          else
            @account.related_councilmember ||= RelatedCouncilmember.new
            @account.related_councilmember.name = params[:account][:related_councilmember_attributes][:name].join(' ')
          end
        else
          if params[:account].has_key?(:related_councilmember_attributes)
              @my_update_hash[:related_councilmember_attributes][:relationship] = "none"
              @my_update_hash[:related_councilmember_attributes][:name] = "none"
          end
        end
        
        if(params[:account][:is_current_worker] == "1") 
          @account.current_worker ||= CurrentWorker.new
        else
          @account.current_worker ||= CurrentWorker.new
          if params[:account].has_key?(:current_worker_attributes)
              @my_update_hash[:current_worker_attributes][:department] = "none"
              @my_update_hash[:current_worker_attributes][:name] = "none" 
          end
        end
        
        if(params[:account][:has_convictions] == "1") 
          @account.former_criminal ||= FormerCriminal.new
        else
          @account.former_criminal ||= FormerCriminal.new
          if params[:account].has_key?(:former_criminal_attributes)
              @my_update_hash[:former_criminal_attributes][:date_of_conviction] = "1991-1-1"
              @my_update_hash[:former_criminal_attributes][:nature_of_offense] = "none" 
              @my_update_hash[:former_criminal_attributes][:name_of_court] = "none"
              @my_update_hash[:former_criminal_attributes][:disposition_of_case] = "none" 
              @my_update_hash[:former_criminal_attributes][:former_crime] = "none"
          end
        end
        
        if(params[:account][:need_accommodations] == "1") 
          @account.accommodation ||= Accommodation.new
        else
          @account.accommodation ||= Accommodation.new
          if params[:account].has_key?(:accommodation_attributes)
              @my_update_hash[:accommodation_attributes][:accommodation_name] = "none"
          end
        end
        
        correct_DOB_format_update(@my_update_hash)
        
        if params[:account][:homephone].gsub(/\D/, '').length == 10   #change homephone format to xxx-xxx-xxxx
         @my_update_hash[:homephone] = params[:account][:homephone].gsub(/\D/, '').insert(3, '-').insert(7, '-')
        end
        
        if params[:account][:emergency_phone].gsub(/\D/, '').length == 10   #change homephone format to xxx-xxx-xxxx
         @my_update_hash[:emergency_phone] = params[:account][:emergency_phone].gsub(/\D/, '').insert(3, '-').insert(7, '-')
        end
        
        if params[:account][:emergency_phone_alternate].gsub(/\D/, '').length == 10   #change homephone format to xxx-xxx-xxxx
         @my_update_hash[:emergency_phone_alternate] = params[:account][:emergency_phone_alternate].gsub(/\D/, '').insert(3, '-').insert(7, '-')
        end

        if params[:account][:cellphone].gsub(/\D/, '').length == 10   #change homephone format to xxx-xxx-xxxx
         @my_update_hash[:cellphone] = params[:account][:cellphone].gsub(/\D/, '').insert(3, '-').insert(7, '-')
        end
    
    
        if @account.update(@my_update_hash) #unless destroyed?  #save(:validate => true)
         
        if(params[:account][:is_former_worker] == "0")
            if(@account.user_formerworker != nil)
                @account.user_formerworker.destroy
            end
        end
        if(params[:account][:related_to_councilmember] == "0") 
          if @account.related_councilmember != nil
              @account.related_councilmember.destroy
          end
        end
        if(params[:account][:is_current_worker] == "0") 
          if @account.current_worker != nil  
              @account.current_worker.destroy
          end
        end
        if(params[:account][:has_convictions] == "0") 
          if @account.former_criminal != nil  
              @account.former_criminal.destroy
          end
        end
        if(params[:account][:need_accommodations] == "0") 
          if @account.accommodation != nil   
              @account.accommodation.destroy
          end
        end
       

        flash[:success] = 'Changes Saved!'
          
        redirect_to action: 'profiles'
        
        else

        flash[:warning] = @account.errors.full_messages;

        flash[:danger] = 'Save changes failed!'

        redirect_to profiles_path #:id => @account.id
        end
     else

         flash[:warning] = 'Your profile is under processing, if you want to make any changes please contact our administrator!'

         redirect_to profiles_path
     end

  end
  
  def save_and_submit
      @account = Account.find(session[:id])
      if @account.submit_bcheck == false && @account.status == nil      #if never submit, then save and submit        
          if @account.update_columns(submit_bcheck: true)

              flash[:success] = 'Your profile has been sent to the administrator'

     #     redirect_to profiles_path :id => @account.id
     # else                                                   # if have already submitted, return to page and do nothing
     #     redirect_to profiles_path :id => @account.id

          else
          flash[:danger] = 'Submission is failed'  
          end
      else     
          if @account.status == true  
          flash[:success] = 'You are approved, no need to bother our administrator right? LOL'# if have submitted, return to page and do nothing
          elsif @account.status == false
          flash[:warning] = 'We are sorry that your profile is rejected, you can not submit again'  
          else
          flash[:info] = 'Your profile is under processing!'
          end
      end
      redirect_to profiles_path #:id => @account.id
      
  end
     
  
  def save_change
      @account = Account.find(params[:id])
  end  
  

  #change password
  def input_your_email
      if params[:email]
        @account = Account.find_by(email: params[:email])
        if @account
          session[:id]= @account.id
          Mailer.reset_password_email(@account).deliver_now
          redirect_to check_your_email_path
          flash[:success] = "Email has been resent, please check it."
        else
          flash.now[:danger] = 'Your email is not valid or it has not been registered, please try again!'
          render 'input_your_email'
        end
      end
  end
  
  def resend_your_email
     @account = Account.find(session[:id])
     Mailer.reset_password_email(@account).deliver_now
     flash[:success] = "Email has been resent, please check it."
  end
  
  def reset_your_password
     @account = Account.find(session[:id])
  end
   
   def validate_password(password)
     if password.length<6 || password.length>20
      return nil
    end
    return 1
  end
  
   def save_password_change
      @account = Account.find(session[:id])
     
       if (params[:account][:password] == params[:account][:password_confirmation])
          if validate_password(params[:account][:password])
             @account.password = params[:account][:password]
             if @account.save
            flash[:success] = "You have reset your password successfully."
            redirect_to login_path
             else 
            flash[:warning] = "Sorry, your password is not saved successfully, please input again!"
            render 'reset_your_password'
              end
         else
           flash[:warning] = "Passwords are not satisfied the requirement."
           flash[:info] = "Your password must be 6-20 characters and cannot be blank."
           render 'reset_your_password'
         end
       else
          flash[:warning]="The passwords you entered must be the same!"
          render 'reset_your_password'
       end
   end
   
private
  
  def account_params

   params.require(:account).permit(:gender, :email,:password, :password_confirmation,:firstname,:lastname, :middlename,:maidenname,:country,:state,:city,:street,:zip,:homephone,:cellphone,:DOB)
  end
  
  def account_update_params
   params.require(:account).permit(:password, :password_confirmation,:is_former_worker,:is_current_worker, :emergency_contact_name,
                                  :emergency_phone,:emergency_phone_alternate,:related_to_councilmember,
                                  :has_convictions, :need_accommodations, :is_volunteering,  :is_student,
                                  :firstname, :lastname, :DOB, :homephone, :cellphone, :street, :city, :state, :zip,
                                  :middlename, :email, :country, :maidenname,
                                  current_worker_attributes: [:id, :department, :name],
                                  user_formerworker_attributes: [:id, :date_of_employment, :reason_for_leaving, :position_or_department],
                                  former_criminal_attributes: [:id, :date_of_conviction, :nature_of_offense, :name_of_court, :disposition_of_case, :former_crime],
                                  related_councilmember_attributes: [:id, :name, :relationship],
                                  accommodation_attributes: [:id, :accommodation_name],
                                  application_form_attributes: [:id, :signature, :interested_areas, :volunteering_status, :application_date, :available_time_begin, :available_time_end],
                                  criminal_application_attributes: [:id, :mandatory_hours, :mandatory_area, :deadline],
                                  student_application_attributes: [:id, :student_program, :required_area, :required_time, :deadline],
                                  minor_application_attributes: [:id, :parent_signature])
                                
  end


end
