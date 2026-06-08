import pytest
from unittest.mock import patch, MagicMock
from pathlib import Path
from app.engine.spice_engine import run_simulation

# Assuming your module is named spice_engine.py
# from spice_engine import run_simulation

@patch("app.engine.spice_engine.generate_netlist")
@patch("app.engine.spice_engine.SimRunner")
@patch("app.engine.spice_engine.RawRead")
def test_run_simulation(mock_rawread_class, mock_simrunner_class, mock_generate_netlist, tmp_path):
    """
    Test run_simulation file writing, directory creation, and subprocess calls.
    Utilizes pytest's tmp_path to prevent writing actual files to the project directory.
    """
    # 1. Setup Data
    mock_schematic = MagicMock()
    mock_generate_netlist.return_value = "* Mocked Netlist Content\nV1 1 0 DC 5 AC 1\n.op\n.tran 1ms 10ms\n.ac dec 10 1 100k\n.end\n"

    # We will use the pytest temporary path as our output directory
    fake_output_dir = tmp_path / "test_sim_output"
    expected_raw_file = str(fake_output_dir / "circuit.raw")
    expected_log_file = str(fake_output_dir / "circuit.log")

    # 2. Setup Mocks
    # Mock the SimRunner instance and its run_now method
    mock_runner_instance = MagicMock()
    mock_simrunner_class.return_value = mock_runner_instance
    mock_runner_instance.run_now.return_value = (expected_raw_file, expected_log_file)

    # Mock the RawRead instance and its to_csv method
    mock_rawread_instance = MagicMock()
    mock_rawread_class.return_value = mock_rawread_instance

    # 3. Execute Function
    result = run_simulation(mock_schematic, output=str(fake_output_dir))

    # 4. Assertions

    # Check that the directory and the .cir file were successfully created
    generated_netlist_path = fake_output_dir / "circuit.cir"
    assert fake_output_dir.exists(), "Output directory was not created."
    assert generated_netlist_path.exists(), "Netlist file was not written."

    # UPDATED ASSERT STRING: Matches the mock above, but without the trailing \n
    expected_file_content = "* Mocked Netlist Content\nV1 1 0 DC 5 AC 1\n.op\n.tran 1ms 10ms\n.ac dec 10 1 100k\n.end"
    assert generated_netlist_path.read_text(encoding="utf-8") == expected_file_content

    # Check that SimRunner was initialized with the correct directory
    mock_simrunner_class.assert_called_once()
    assert mock_simrunner_class.call_args[1]["output_folder"] == str(fake_output_dir)

    # Check that runner.run_now was called with the right file paths
    mock_runner_instance.run_now.assert_called_once_with(
        str(generated_netlist_path),
        run_filename=str(generated_netlist_path)
    )

    # Check that RawRead converted the output to CSV correctly
    mock_rawread_class.assert_called_once_with(expected_raw_file)
    expected_csv_out = Path(expected_raw_file).with_suffix(".csv")
    mock_rawread_instance.to_csv.assert_called_once_with(expected_csv_out)

    # Verify the final return value
    assert result == expected_raw_file