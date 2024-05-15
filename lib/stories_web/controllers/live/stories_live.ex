defmodule StoriesWeb.StoriesLive do
  alias Stories.OpenAi
  use StoriesWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       story: "",
       villain: "Boy evil turtle",
       hero: "Ninja boy with two large swords and extreme speed",
       kid: "4 year old",
       story_theme: "stealing apples",
       story_length: "5 minutes at slow pace",
       story_tone: "gentle",
       image: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <form phx-submit="generate_story">
        <div class="mt-10 grid grid-cols-3 gap-x-6 gap-y-8 ">
          <.input label="Name the hero!!" type="text" name="hero" value={@hero} />
          <.input label="Describe kid!!" type="text" name="kid" value={@kid} />
          <.input label="Name the villain!" type="text" name="villain" value={@villain} />
          <.input label="Name the theme!" type="text" name="story_theme" value={@story_theme} />
          <.input label="Length of story!" type="text" name="story_length" value={@story_length} />
          <.input label="Overall tone!" type="text" name="story_tone" value={@story_tone} />
        </div>

        <.button>GO!</.button>
      </form>

      <div class="flex flex-col md:flex-row items-center justify-center gap-x-8 gap-y-5 my-10 mx-4 md:mx-10">
        <div class="w-1/2 text-center md:text-left">
          <p class="text-gray-600">
            <%= raw(@story) %>
          </p>
        </div>
        <div class="w-1/2">
          <img
            :if={not is_nil(assigns.image)}
            class="w-full object-cover rounded-md"
            src={"data:image/jpeg;base64,#{@image}"}
          />
        </div>
      </div>
    </div>
    """
  end

  def handle_event("generate_story", params, socket) do
    %{
      "hero" => hero,
      "kid" => kid,
      "story_length" => story_length,
      "story_tone" => story_tone,
      "story_theme" => theme,
      "villain" => villain
    } = params

    story_prompt =
      """
      Please, write a #{story_length} short story for a #{kid}, so please no big words.
      The tale should feature an unconventional hero - #{hero}.
      The #{hero} is not a typical hero but has unique attributes and strengths. Describe a single situation where these peculiarities assist #{hero} in surprising ways.
      The journey should feature a villain - #{villain}. This villain's backstory needs to be complex and interesting. Describe how #{villain} past experiences, especially those connected with #{hero}, led them down the path of villainy.
      The theme of the story is #{theme}. Explore how this theme is relevant to both #{hero} and #{villain}.
      Aim for a #{story_tone} tone. Keep in mind that the story should stimulate children's imagination. It can be whimsical, playful, and filled with unexpected twists.
      Introduce at least one amusing joke or funny situation that's suitable for a child's understanding and sense of humor.
      Remember to divide the story into different sections or 'episodes' represented by paragraphs, each with its unique mini-adventure or problem-solving sequence.
      A final super battle at the end of the story is a must. The battle should be exciting and filled with action, but not too violent or scary.
      There is no need for a moral or lesson at the end of the story.
      I just want the child to have fun and be entertained, and for #{hero} to beat #{villain}.
      Please wrap story paragraphs in html paragraph tags.
      """

    image_prompt = """
    Can you draw me a cartoonish picture hero #{hero} fighting villain #{villain}.
    Colors should be bright and vivid.
    Image theme is #{theme}.
    Without any text on the picture.
    Hero must have a brave and determined face, and villain should be scared.
    """

    generate_image(image_prompt)
    story_prompt |> OpenAi.stream() |> stream_response()

    {:noreply, assign(socket, image: nil, story: "")}
  end

  def handle_info({:render_response_chunk, chunk}, socket) do
    story = socket.assigns.story
    story = story <> chunk
    {:noreply, assign(socket, :story, story)}
  end

  def handle_info({:render_image, content}, socket),
    do: {:noreply, assign(socket, :image, content)}

  def handle_info(_out, socket) do
    {:noreply, socket}
  end

  defp stream_response(stream) do
    target = self()

    Task.Supervisor.async(Stories.TaskSupervisor, fn ->
      for chunk <- stream, into: <<>> do
        send(target, {:render_response_chunk, chunk})
        chunk
      end
    end)
  end

  defp generate_image(image_prompt) do
    target = self()

    Task.Supervisor.async(Stories.TaskSupervisor, fn ->
      content = OpenAi.generate_image(image_prompt)
      send(target, {:render_image, content})
    end)
  end
end
