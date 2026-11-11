import pytest

from api.grid import parse_filters


def test_column_filters_trim_empty_values_and_require_text_mapping() -> None:
    assert parse_filters('{"name":"  mix  ","branch_code":"  "}') == {"name": "mix"}
    with pytest.raises(ValueError, match="JSON object"):
        parse_filters("[")
    with pytest.raises(ValueError, match="map column names"):
        parse_filters('{"name":1}')
