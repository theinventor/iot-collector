class CollectorAccessController < ApplicationController
  def create
    key = params[:key].to_s
    if ::Collector.find_by_key(key)
      remember_collector_key(key)
      redirect_to root_path, status: :see_other
    else
      @invalid_key = true
      render "dashboard/access_required", status: :unauthorized
    end
  end

  def destroy
    forget_collector_key
    redirect_to root_path, status: :see_other
  end
end
