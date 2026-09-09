struct Style {
	size  int
	color int
}

struct Theme {
	b3 Style
}

interface View {
	tag int
}

struct TextCfg {
	style Style
}

struct BoxCfg {
	content []View
}

struct Node implements View {
	tag int
}

fn theme() Theme {
	return Theme{}
}

fn text(c TextCfg) View {
	return Node{ tag: c.style.size }
}

fn box(c BoxCfg) View {
	return Node{ tag: c.content.len }
}

fn main() {
	local_style := theme().b3
	mut views := []View{}
	if views.len > 0 {
		views << box(content: [])
	} else {
		views << box(
			content: [
				text(
					style: Style{
						...local_style
						color: 9
					}
				),
			]
		)
	}
	println(views.len)
}
