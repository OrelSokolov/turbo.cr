# Behavioral specs for turbo_frame_tag extended opts + static form
# (no oracle regen: the turbo-rails gem oracle needs rails+PG; parity
# gate for the app is twinshot. Byte order of the 3 base cases is
# pinned by oracle_spec helper_turbo_frame_tag*).

require "spec"
require "../src/turbo_cr"

class TurboFrameView
  include Turbo::FramesHelper
  include ActionView::Helpers::TagHelper
end

describe "turbo_frame_tag opts" do
  view = TurboFrameView.new

  it "base cases keep oracle bytes" do
    view.turbo_frame_tag("frame1").to_s.should eq %(<turbo-frame id="frame1"></turbo-frame>)
    view.turbo_frame_tag("frame1", src: "/posts", loading: "lazy").to_s
      .should eq %(<turbo-frame loading="lazy" id="frame1" src="/posts"></turbo-frame>)
  end

  it "extra attributes pass through (target, data: nested, bool)" do
    view.turbo_frame_tag(:user_sidebar, src: "/users/me/sidebar", target: "_top",
      data: {"turbo_permanent" => true, "controller" => "rooms-list"}).to_s
      .should eq %(<turbo-frame target="_top" data-turbo-permanent="true" data-controller="rooms-list" id="user_sidebar" src="/users/me/sidebar"></turbo-frame>)
  end

  it "Symbol frame_id underscores as-is (no camelize in this gem)" do
    html = view.turbo_frame_tag(:user_sidebar).to_s
    html.should contain %(id="user_sidebar")
  end

  it "block content escapes plain strings, passes SafeString" do
    view.turbo_frame_tag("f") { "<p>x</p>" }.to_s
      .should eq %(<turbo-frame id="f">&lt;p&gt;x&lt;/p&gt;</turbo-frame>)
    view.turbo_frame_tag("f") { ActionView::SafeString.new("<p>x</p>") }.to_s
      .should eq %(<turbo-frame id="f"><p>x</p></turbo-frame>)
  end

  it "static module form matches instance form" do
    static = Turbo::FramesHelper.turbo_frame_tag("user_sidebar", "/users/me/sidebar", nil,
      {"target" => ActionView::Helpers::TagHelper.__av_normalize_val("_top"),
       "data"   => ActionView::Helpers::TagHelper.__av_normalize_val(
         {"turbo_permanent" => true})} of String => ActionView::Helpers::TagHelper::AttrVal).to_s
    static.should eq view.turbo_frame_tag("user_sidebar",
      src: "/users/me/sidebar", target: "_top",
      data: {"turbo_permanent" => true}).to_s
  end
end
