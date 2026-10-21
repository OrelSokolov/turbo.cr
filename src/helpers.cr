# View-хелперы turbo: turbo_stream / turbo_stream_from (StreamsHelper)
# и turbo_frame_tag (FramesHelper). 1:1 с app/helpers гема; порядок
# атрибутов зафиксирован оракулом (data → channel → signed-stream-name).

module Turbo
  module StreamsHelper
    # TagBuilder для шаблонов и контроллеров.
    def turbo_stream : Turbo::Streams::TagBuilder
      Turbo::Streams::TagBuilder.new(self)
    end

    # <turbo-cable-stream-source> — подписка на стрим через
    # Turbo::StreamsChannel. channel: — имя кастомного канала,
    # data: — доп. data-атрибуты канала.
    def turbo_stream_from(*streamables : Turbo::Streamable, channel : String? = nil,
                          data : Hash(String, String)? = nil) : ActionView::SafeString
      unless streamables.any? { |s| !s.is_a?(String) || !s.blank? }
        raise ArgumentError.new("streamables can't be blank")
      end
      opts = {} of String => ActionView::Helpers::TagHelper::AttrVal
      if data
        # Rails dasherizes data-ключи: {room_name:} -> data-room-name.
        # AttrVal — рекурсивный union, Hash(String, String) туда не
        # присваивается (инвариантность генериков) — строим сразу
        # Hash(String, AttrVal).
        dashed = {} of String => ActionView::Helpers::TagHelper::AttrVal
        data.each { |k, v| dashed[k.gsub('_', '-')] = v.to_s }
        opts["data"] = dashed
      end
      opts["channel"] = channel || "Turbo::StreamsChannel"
      opts["signed-stream-name"] = Turbo::StreamsChannel.signed_stream_name(streamables.to_a)
      ActionView::SafeString.new("<turbo-cable-stream-source#{tag_options(opts)}></turbo-cable-stream-source>")
    end
  end

  module FramesHelper
    # <turbo-frame id="..." [src=...] [loading=...]>; блочная форма —
    # содержимое блока экранируется (content_tag-семантика Rails),
    # SafeString проходит как есть.
    # Доп. атрибуты (**opts: target, class, data: {...} и т.д.) идут
    # ПОСЛЕ пользовательских и ДО loading/id/src — как порядок вставки
    # ключей в turbo_frame_tag гема. Статик-форма
    # (FramesHelper.turbo_frame_tag c opts-Hash) — для дом-билдеров вне
    # вью-контекста (ChatLayout-стиль), как TagHelper.tag_options.
    def turbo_frame_tag(frame_id : String | Symbol, src : String? = nil,
                        loading : String? = nil, **opts,
                        &block : Proc(String | ActionView::SafeString)) : ActionView::SafeString
      h = {} of String => ::ActionView::Helpers::TagHelper::AttrVal
      opts.each { |k, v| h[k.to_s] = ActionView::Helpers::TagHelper.__av_normalize_val(v) }
      result = block.call
      inner = result.is_a?(ActionView::SafeString) ? result.to_s : HTML.escape(result.to_s)
      Turbo::FramesHelper.__frame_html(frame_id, src, loading, h, inner)

    end

    def turbo_frame_tag(frame_id : String | Symbol, src : String? = nil,
                        loading : String? = nil, **opts) : ActionView::SafeString
      h = {} of String => ::ActionView::Helpers::TagHelper::AttrVal
      opts.each { |k, v| h[k.to_s] = ActionView::Helpers::TagHelper.__av_normalize_val(v) }
      Turbo::FramesHelper.__frame_html(frame_id, src, loading, h, "")
    end
  end
end

module Turbo
  module FramesHelper
    # opts — преднормализованный Hash(String, TagHelper::AttrVal):
    # пользовательские атрибуты (target/class/data/…), порядок вставки
    # ДО loading/id/src.
    def self.turbo_frame_tag(frame_id : String | Symbol, src : String? = nil,
                             loading : String? = nil,
                             opts : Hash = {} of String => ::Nil,
                             &block : Proc(String | ActionView::SafeString)) : ActionView::SafeString
      attrs = Turbo::FramesHelper.__frame_attrs(frame_id, src, loading, opts)
      result = block.call
      inner = result.is_a?(ActionView::SafeString) ? result.to_s : HTML.escape(result.to_s)
      __frame_html_with(frame_id, attrs, inner)
    end

    def self.turbo_frame_tag(frame_id : String | Symbol, src : String? = nil,
                             loading : String? = nil,
                             opts : Hash = {} of String => ::Nil) : ActionView::SafeString
      attrs = Turbo::FramesHelper.__frame_attrs(frame_id, src, loading, opts)
      __frame_html_with(frame_id, attrs, "")
    end

    def self.__frame_attrs(frame_id : String | Symbol, src : String?, loading : String?,
                           opts : Hash) : Hash(String, ActionView::Helpers::TagHelper::AttrVal)
      attrs = {} of String => ActionView::Helpers::TagHelper::AttrVal
      # Нормализация (idempotent): публичная статик-форма принимает сырые
      # значения (String/Bool/вложенный data-Hash), инстанс-путь может
      # передавать уже нормализованные.
      opts.each { |k, v| attrs[k.to_s] = ActionView::Helpers::TagHelper.__av_normalize_val(v) }
      attrs["loading"] = loading if loading
      attrs["id"] = frame_id.to_s
      attrs["src"] = src if src
      attrs
    end

    def self.__frame_html(frame_id : String | Symbol, src : String?, loading : String?,
                          opts : Hash, inner : String) : ActionView::SafeString
      __frame_html_with(frame_id, __frame_attrs(frame_id, src, loading, opts), inner)
    end

    private def self.__frame_html_with(frame_id : String | Symbol,
                                       attrs : Hash(String, ActionView::Helpers::TagHelper::AttrVal),
                                       inner : String) : ActionView::SafeString
      ActionView::SafeString.new("<turbo-frame#{ActionView::Helpers::TagHelper.tag_options(attrs)}>#{inner}</turbo-frame>")
    end
  end
end
