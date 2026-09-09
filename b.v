struct Style {
	size  int
	color int
}

struct View {
	tag int
}

struct TextCfg {
	text  string
	style Style
}

struct BoxCfg {
	id      int
	content []View
}

fn base() Style {
	return Style{ size: 10, color: 1 }
}

fn text(c TextCfg) View {
	return View{ tag: c.style.size }
}

fn box(c BoxCfg) View {
	return View{ tag: c.content.len + c.id }
}

fn main() {
	mut views := []View{}
	views << box(
		id:      3
		content: [
			text(
				text:  'hi'
				style: Style{
					...base()
					color: 2
				}
			),
		]
	)
	println(views)
}
