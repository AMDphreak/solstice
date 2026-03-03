import dlangui;
import std.datetime;
import std.math;
import std.conv : to;
import std.algorithm;

mixin APP_ENTRY_POINT;

/// Simple solar position calculator
struct SolarResult
{
	double sunrise; // hours from midnight
	double sunset; // hours from midnight
	double declination;
}

SolarResult calculateSolar(double lat, double lon, Date date)
{
	int dayOfYear = date.dayOfYear;
	double decl = 23.45 * sin((360.0 / 365.0 * (dayOfYear - 81)) * PI / 180.0);
	double latRad = lat * PI / 180.0;
	double declRad = decl * PI / 180.0;
	double cosOmega = -tan(latRad) * tan(declRad);
	double omega;
	if (cosOmega <= -1)
		omega = PI;
	else if (cosOmega >= 1)
		omega = 0;
	else
		omega = acos(cosOmega);
	double omegaDegrees = omega * 180.0 / PI;
	double halfDayHours = omegaDegrees / 15.0;
	double solarNoon = 12.0 - (lon / 15.0);
	return SolarResult(solarNoon - halfDayHours, solarNoon + halfDayHours, decl);
}

class SunMoonWidget : Widget
{
	double latitude = 51.5074; // London
	double longitude = 0.1278;
	bool showLocation = true;

	this(string ID)
	{
		super(ID);
	}

	override void onDraw(DrawBuf buf)
	{
		if (visibility != Visibility.Visible)
			return;
		super.onDraw(buf);
		Rect rc = _pos;
		applyMargins(rc);
		applyPadding(rc);

		int centerX = rc.left + rc.width / 2;
		int centerY = rc.top + rc.height / 2;
		int radius = min(rc.width, rc.height) / 2 - 30;
		if (radius < 10)
			return;

		auto now = Clock.currTime();
		double currentHour = now.hour + now.minute / 60.0 + now.second / 3600.0;
		auto solar = calculateSolar(latitude, longitude, cast(Date) now);

		uint colorSkyDay = 0xFF1E90FF;
		uint colorSkyNight = 0xFF000033;
		uint colorSun = 0xFFFFD700;
		uint colorMoon = 0xFFE6E6FA;

		bool isDay = (currentHour >= solar.sunrise && currentHour <= solar.sunset);
		uint bgColor = isDay ? colorSkyDay : colorSkyNight;
		buf.drawEllipseF(centerX, centerY, radius, radius, 1, bgColor, bgColor);

		double hourToAngle(double h)
		{
			return (h / 24.0) * 2.0 * PI - PI / 2.0;
		}

		for (int i = 0; i < 24; i++)
		{
			double ang = (i / 24.0) * 2.0 * PI - PI / 2.0;
			float innerR = radius - (i % 6 == 0 ? 10 : 5);
			int x1 = cast(int)(centerX + innerR * cos(ang));
			int y1 = cast(int)(centerY + innerR * sin(ang));
			int x2 = cast(int)(centerX + radius * cos(ang));
			int y2 = cast(int)(centerY + radius * sin(ang));
			buf.drawLine(Point(x1, y1), Point(x2, y2), i % 6 == 0 ? 0xFFFFFFFF : 0xFF888888);
		}

		double sunAng = hourToAngle(currentHour);
		int sunX = cast(int)(centerX + (radius - 40) * cos(sunAng));
		int sunY = cast(int)(centerY + (radius - 40) * sin(sunAng));
		if (isDay)
		{
			buf.drawEllipseF(sunX, sunY, 15, 15, 0, 0, colorSun);
		}
		else
		{
			buf.drawEllipseF(sunX, sunY, 10, 10, 0, 0, 0xFF333300);
		}

		double moonAng = sunAng + PI;
		int moonX = cast(int)(centerX + (radius - 40) * cos(moonAng));
		int moonY = cast(int)(centerY + (radius - 40) * sin(moonAng));
		buf.drawEllipseF(moonX, moonY, 12, 12, 0, 0, colorMoon);

		double indAng = hourToAngle(currentHour);
		int indX = cast(int)(centerX + radius * cos(indAng));
		int indY = cast(int)(centerY + radius * sin(indAng));
		buf.drawLine(Point(centerX, centerY), Point(indX, indY), 0xFFFF4500);
		buf.drawEllipseF(indX, indY, 6, 6, 0, 0, 0xFFFF4500);

		if (showLocation)
		{
			FontRef fnt = font;
			if (fnt.isNull)
				fnt = FontManager.instance.getFont(14, FontWeight.Normal, false, FontFamily.SansSerif, "Arial");
			dstring locStr = ("Lat: " ~ to!string(latitude) ~ " Lon: " ~ to!string(longitude))
				.to!dstring;
			fnt.drawText(buf, centerX - 60, centerY + radius + 15, locStr, 0xFFCCCCCC);
		}
	}
}

class MainView : VerticalLayout
{
	private SunMoonWidget _widget;
	private ScrollWidget _settingsPanel;
	private EditLine _latEdit;
	private EditLine _lonEdit;
	private CheckBox _showLocCheck;
	private int _dragStartX;
	private int _dragStartY;

	this()
	{
		super("main_view");
		layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).backgroundColor(0xFF121212);

		auto header = new HorizontalLayout();
		header.layoutWidth(FILL_PARENT).layoutHeight(WRAP_CONTENT);
		header.addChild(new HSpacer().layoutWidth(FILL_PARENT));

		auto settingsBtn = new Button("settings_btn", "⚙"d);
		settingsBtn.styleId = "BUTTON_TRANSPARENT";
		settingsBtn.layoutWidth(32).layoutHeight(32).margins(Rect(5, 5, 5, 5));
		settingsBtn.click = delegate(Widget w) {
			_settingsPanel.visibility = (_settingsPanel.visibility == Visibility.Visible) ? Visibility.Gone
				: Visibility.Visible;
			return true;
		};
		header.addChild(settingsBtn);
		addChild(header);

		_settingsPanel = new ScrollWidget("settings_panel");
		_settingsPanel.layoutWidth(FILL_PARENT).layoutHeight(WRAP_CONTENT)
			.backgroundColor(0xFF2D2D2D).padding(10);
		_settingsPanel.visibility = Visibility.Gone;

		auto settingsContent = new VerticalLayout();
		settingsContent.addChild(new TextWidget(null, "Settings"d)
				.textColor(0xFFFFFFFF).fontSize(18));
		settingsContent.addChild(new TextWidget(null, "Latitude:"d).textColor(0xFFCCCCCC));
		_latEdit = new EditLine("lat_edit", "51.5074"d);
		settingsContent.addChild(_latEdit);
		settingsContent.addChild(new TextWidget(null, "Longitude:"d).textColor(0xFFCCCCCC));
		_lonEdit = new EditLine("lon_edit", "0.1278"d);
		settingsContent.addChild(_lonEdit);
		_showLocCheck = new CheckBox("show_loc_check", "Show Location"d);
		_showLocCheck.checked = true;
		settingsContent.addChild(_showLocCheck);

		auto applyBtn = new Button("apply_btn", "Apply"d);
		applyBtn.click = delegate(Widget w) {
			try
			{
				_widget.latitude = to!double(_latEdit.text);
				_widget.longitude = to!double(_lonEdit.text);
				_widget.showLocation = _showLocCheck.checked;
				_widget.requestLayout();
				_settingsPanel.visibility = Visibility.Gone;
			}
			catch (Exception e)
			{
			}
			return true;
		};
		settingsContent.addChild(applyBtn);
		_settingsPanel.contentWidget = settingsContent;
		addChild(_settingsPanel);

		_widget = new SunMoonWidget("sun_moon");
		_widget.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
		addChild(_widget);

		setTimer(1000);
	}

	override bool onTimer(ulong id)
	{
		_widget.invalidate();
		return true;
	}

	override bool onMouseEvent(MouseEvent event)
	{
		if (event.action == MouseAction.ButtonDown && event.button == MouseButton.Left)
		{
			_dragStartX = event.x;
			_dragStartY = event.y;
			return true;
		}
		if (event.action == MouseAction.Move && (event.flags & MouseFlag.LButton))
		{
			if (window)
			{
				Rect wr = window.windowRect;
				window.moveWindow(Point(wr.left + event.x - _dragStartX, wr.top + event.y - _dragStartY));
			}
			return true;
		}
		return super.onMouseEvent(event);
	}
}

extern (C) int UIAppMain(string[] args)
{
	Window window = Platform.instance.createWindow("Solstice Widget"d, null, WindowFlag.Resizable | WindowFlag
			.Borderless, 350, 400);
	window.mainWidget = new MainView();
	window.show();
	return Platform.instance.enterMessageLoop();
}
