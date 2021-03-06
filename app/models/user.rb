class User < ActiveRecord::Base
##常量定义##
#定义用户类型
  TYPE_ADMIN = 0 #超级管理员
  TYPE_DIRECTOR = 1 #组长，管理单个养老院
  TYPE_VOLUNTEER = 2 #志愿者，权限最低
#定义用户头像的小图和中图最大宽高
  AVATAR_SW = 100
  AVATAR_SH = 100
  AVATAR_NW = 300
  AVATAR_NH = 300
##可用参数##
  attr_accessor :crop_x, :crop_y, :crop_w, :crop_h

##模型关系##
#for the admin user_type==0

#for directors user_type==1
  has_many :managements, dependent: :destroy
  has_many :nursing_homes, through: :managements
#for volunteers user_type==2
  has_many :applications, dependent: :destroy
  has_many :assignments, dependent: :destroy
  has_many :records
  has_many :attended_applications, -> {where(verified: true, attended: true)}, class_name: "Application"
  has_many :attended_projects, through: :attended_applications, source: :project
  has_many :absent_applications, -> {where(verified: true, attended: false)}, class_name: "Application"
  has_many :absent_projects, through: :absent_applications, source: :project
  has_many :sent_messages, :foreign_key => "sender_id", :class_name => "Message"
  has_many :received_messages, :class_name => "Message"
  has_many :system_messages, -> { where(sender_id: 0) }, :class_name => "Message"

##数据验证##
  #binding.pry
  validates :email, :presence => { :message => '亲，邮箱可不能为空' },
            :uniqueness =>{:message => "亲，这个邮箱已经注册过了" },
            :format => { :with => /\A\w+([-+.]\w+)*@\w+([-.]\w+)*\.[a-z]+\Z/, :message => "您这是邮箱吗?" }
  validates :password, :presence => { :message => '亲，密码可不能为空' },
            :length => { :in => 8..128, :too_short => '不要这么短哦', :too_long  => '不要这么长哦'},
            :confirmation => {:message => '亲，要一样哦'}
  validates :phone_number, :presence => { :message => '电话一定要填的' }


  has_attached_file :avatar,
    :default_url => "/images/default_avatar.png", 
    :hash_secret => "efb40e6f2783c6d6641db8f1accdce15", 
    :styles => { :medium => "#{Constants::AVATAR_NW}x#{Constants::AVATAR_NH}>", :thumb => "#{Constants::AVATAR_SW}x#{Constants::AVATAR_SH}>" },
    :processors => [:jcropper],
    :dependent => :destroy
  validates_attachment :avatar,
    :content_type => { :content_type => /\Aimage\/.*\Z/ },
    :size => { :in => 0..4096.kilobytes }

##公共方法##

#是否有要求的裁剪参数  
  def cropping?
    !crop_x.blank? && !crop_y.blank? && !crop_w.blank? && !crop_h.blank?
  end

#裁剪时获取图片原始尺寸
  def avatar_geometry(style = :original)
    @geometry ||= {}
    @geometry[style] ||= Paperclip::Geometry.from_file avatar.path(style)
  end

#注册邮箱查重
  def self.check_email_available(checked_email)
    self.where("email = '#{checked_email}'").empty?
  end
#用户登录验证
  def self.authenticate(email, password)
    user = find_by_email(email)
    (user && user.password == password)? user : nil
  end

#计算年龄，周岁
  def age
    age = Time.now.year - birthday.year
    (Time.now.month > birthday.month or (Time.now.month == birthday.month and Time.now.day >= birthday.day))? age : (age-1)
  end

#是否管理员
  def admin?
    user_type==Constants::TYPE_ADMIN
  end
#是否组长
  def director?
    user_type==Constants::TYPE_DIRECTOR
  end
#是否志愿者
  def volunteer?
    user_type==Constants::TYPE_VOLUNTEER
  end

#设置为志愿者后清理管理关系
  def clean_management
    Management.where(user_id: id).destroy_all
  end

#查询是否已经申请某个活动
  def has_applied?(project)
    Application.where(user_id: id, project_id: project.id).any?
  end

#返回对某个活动的申请
  def application_of(project)
    Application.where(user_id: id, project_id: project.id)[0]
  end

#查询对某个活动的申请是否已经被分配
  def has_be_assigned?(project)
    Assignment.where(user_id: id, project_id: project.id).any?
  end

#返回对某个活动的分配结果
  def assignment_of(project)
    Assignment.where(user_id: id, project_id: project.id)[0]
  end

#对于志愿者而言的活动分类应该在applications表中添加status字段来表示，通过一次查询得到project_id数组
#添加status的好处在于保存了查询计算结果，避免重复查询计算，用小空间来换取大量时间
#现在采用的方法费时费力，查询速度慢，需要改进。* TO DO *
#可以报名的活动(包括已经报名和尚未报名的活动)，即Project.published
  def regable_projects
    Project.published
  end
#已经报名、报名结束、尚未开始的活动,即user参加的Project.upcoming
  def upcoming_projects
    Project.upcoming.joins(:applications).where(applications: {user_id: id, verified: true})
  end

#已经报名、报名结束、正在进行的活动,即user参加的Project.ongoing
  def ongoing_projects
    Project.ongoing.joins(:applications).where(applications: {user_id: id, verified: true, attended: true})
  end

#已经报名、已经完成、尚未填写关怀记录的活动
  def unfinished_projects
    #NOT EXISTS 和 LEFT JOIN WHERE IS NULL能达到同样的效果，后者运行速度更快
    #Project.finished.joins(:applications).where(applications: {user_id: id, verified: true, attended: true}).where("NOT EXISTS (select * from records where records.user_id = applications.user_id AND records.project_id = applications.project_id)")

    Project.finished.joins(:applications).where(applications: {user_id: id, verified: true, attended: true}).joins("LEFT JOIN records on records.user_id = applications.user_id AND records.project_id = applications.project_id").where("records.user_id IS NULL")

  end
#已经报名，已经参加，已经填写了关怀记录的活动
  def finished_projects
    Project.finished.joins(:applications).where(applications: {user_id: id, verified: true, attended: true}).joins("JOIN records on records.user_id = applications.user_id AND records.project_id = applications.project_id").distinct
  end
#已经完成，但是尚处在修改期的活动,即完成后三天之内
  def modifiable_projects
    #这段代码需要修改，效率低，不能直接用group，rails默认选出id最大的作为代表，而此处需要id最小的。SQL中与rails中group选出的恰好相反。 *TO DO*
    Project.find_by_sql("select projects.* from projects left join (select * from records group by project_id) as records on projects.id = records.project_id where records.user_id = #{id} AND records.created_at > '#{Time.now-3.days}' ")
  end

#参加某个活动的关怀记录
  def records_of(project)
    Record.where(user_id: id, project_id: project.id)
  end

  def unread_messages
    received_messages.where(:status => [0,4] )
  end
#组长拥有的活动，即所管理的所有养老院的活动，
  def projects
    nursing_homes.map(&:projects).flatten
  end

end
