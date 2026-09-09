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

struct A11yCfg {
	a11y_label       string
	a11y_description string
}

@[minify]
struct TextCfg {
	A11yCfg
	style Style
}

@[minify]
struct BoxCfg {
	A11yCfg
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
	mut views := []View{}
	views << if views.len > 0 {
		box(content: [])
	} else {
		box(
			content: [
				text(
					style: Style{
						...theme().b3
						color: 9
					}
				),
			]
		)
	}
	println(views.len)
}
