module BreadcrumbsHelper
  def breadcrumbs
    @breadcrumbs ||= []
  end

  def add_breadcrumb(label, path = nil)
    breadcrumbs << { label: label, path: path }
  end
end
