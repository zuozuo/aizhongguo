class ApplicationsController < ApplicationController
  before_action :set_application, only: [:show, :edit, :update, :destroy]
  before_filter :validate_user_login
  # GET /applications
  # GET /applications.json
  def index
    if params[:project_id].nil?
      @applications = Application.all
    else
      params[:offset] ||= 0
      params[:limit] ||= 1000
      @applications = Project.find_by_id(params[:project_id]).applications.order("id desc").offset(params[:offset]).limit(params[:count])
    end
  end

  # GET /applications/1
  # GET /applications/1.json
  def show
  end

  # GET /applications/new
  def new
    @application = Application.new
  end

  # GET /applications/1/edit
  def edit
  end

  # POST /applications
  # POST /applications.json
  def create
    #binding.pry
    @application = Application.new(application_params.merge({:user_id=>current_user.id}))

    respond_to do |format|
      if @application.save
        #format.html { redirect_to @application, notice: 'Application was successfully created.' }
        format.html { redirect_to controller: "projects", action: "direction", id: @application.project_id }
        format.json { 
          #render :text => "<a rel=\"nofollow\" href=\"/applications/#{@application.id}\" data-method=\"delete\" data-remote=\"true\" class=\"remote-applications-#{@application.id} btn btn-primary\">取消报名</a>" 
        }
      else
        format.html { render :new }
        format.json { render json: @application.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /applications/1
  # PATCH/PUT /applications/1.json
  def update
    respond_to do |format|
      if @application.update(application_params)
        format.html { redirect_to @application, notice: 'Application was successfully updated.' }
        format.json { render :show, status: :ok, location: @application }
      else
        format.html { render :edit }
        format.json { render json: @application.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /applications/1
  # DELETE /applications/1.json
  def destroy
    @application.destroy
    respond_to do |format|
      #format.html { redirect_to applications_url, notice: 'Application was successfully destroyed.' }
      format.json { 
        render :text =>"<button type=\"button\" class=\"btn btn-primary\" data-toggle=\"modal\" data-target=\"#myModal\">报名</button>"
        #render :text => "<a rel=\"nofollow\" href=\"/projects/#{@application.project.id}/applications\" data-method=\"post\" data-remote=\"true\" class=\"remote-#{@application.project.id}-applications btn btn-primary\">报名</a>" 
      }
    end
  end


  def setverified
    @application = Application.find(params[:id])
    if @application.update_attributes(:verified => !@application.verified)
      flash.now[:success] = 'application verified set successfully!'
      if @application.verified
        render :text => "<a href=\"/applications/setverified/#{@application.id}\" data-remote=\"true\" class = \"remote-setverified-#{@application.id}\">已通过，点击取消通过</a>"
      else
        render :text => "<a href=\"/applications/setverified/#{@application.id}\" data-remote=\"true\" class = \"remote-setverified-#{@application.id}\">未通过，点击审核通过</a>"
      end
    else  
      flash.now[:error] = 'fail to verify'
      render :text => "error_message_return:#{flash.now[:error]}"
    end
  end


  def setattended
    @application = Application.find(params[:id])
    if @application.update_attributes(:attended => !@application.attended)
      flash.now[:success] = 'application attended set successfully!'
      if @application.attended
        render :text => "<a href=\"/applications/setattended/#{@application.id}\" data-remote=\"true\" class = \"remote-setattended-#{@application.id}\">已签到，点击取消签到</a>"
      else
        render :text => "<a href=\"/applications/setattended/#{@application.id}\" data-remote=\"true\" class = \"remote-setattended-#{@application.id}\">未签到，点击完成签到</a>"
      end
    else  
      flash.now[:error] = 'fail to change attended'
      render :text => "error_message_return:#{flash.now[:error]}"
    end
  end



  private
    # Use callbacks to share common setup or constraints between actions.
    def set_application
      @application = Application.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def application_params
      (params.permit(:project_id).empty?)? params.require(:application).permit(:project_id, :pickup_site_id) : params.permit(:project_id, :pickup_site_id)
    end
end
